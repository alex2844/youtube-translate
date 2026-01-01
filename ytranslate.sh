#!/usr/bin/env bash
set -euo pipefail

readonly VERSION='2.3.0'
: "${YT_COOKIES:=}"
: "${YT_URL:=}"
: "${YT_LOCAL_PATH:=}"
: "${YT_FROMLANG:="en"}"
: "${YT_TOLANG:="ru"}"
: "${YT_HEIGHT:=0}"
: "${YT_ORIG_VOLUME:=0.15}"
: "${YT_TEMP_DIR:=".ytranslate"}"
: "${YT_OUTPUT_EXT:="mkv"}"
: "${YT_OUTPUT_DIR:="."}"
: "${YT_NO_CLEANUP:=false}"
: "${YT_FORCE_IPV4:=false}"
: "${YT_FORCE_AVC:=false}"
: "${YT_MARK_WATCHED:=false}"
: "${YT_GENERATE_META:=false}"
: "${YT_SPONSORBLOCK:=true}"

CURRENT_CACHE=""
YTDLP_OPTS=(--no-warnings --fragment-retries 10)
if [[ -n "${COLAB_RELEASE_TAG:-}" ]]; then
	INSTALL_DEPENDENCIES="true"
else
	INSTALL_DEPENDENCIES="${INSTALL_DEPENDENCIES:-false}"
fi

function usage() {
	echo "Usage: "$0" [OPTION...] <URL> [LOCAL_FILE]"
	echo "Options:"
	echo "  -h, --help             Show help"
	echo "  -v, --version          Show version"
	echo "  -4, --ipv4             Force IPv4"
	echo "  -r, --height=<int>     Max video height (e.g. 1080). Default: 0 (Best)"
	echo "  -f, --from_lang=<str>  Source language (default: en)"
	echo "  -t, --to_lang=<str>    Target language (default: ru)"
	echo "  -c, --cookies=<path>   Cookies path"
	echo "  -o, --output=<path>    Output directory"
	echo "  --force-avc            Force AVC (h264) video codec"
	echo "  --mark-watched         Mark video as watched (requires cookies)"
	echo "  --meta                 Generate NFO and JPG for Media Centers"
	echo "  --no-sponsorblock      Disable marking sponsor segments (enabled by default)"
	echo "  --temp-dir=<path>      Temporary directory"
	echo "  --no-cleanup           Keep temp files"
	echo ""
	echo "Environment:"
	echo "  INSTALL_DEPENDENCIES   Set 'true' to auto-install packages (default: false)"
	echo ""
	echo "Examples:"
	echo "  "$0" https://youtu.be/VIDEO_ID"
	echo "  "$0" https://youtu.be/VIDEO_ID my_video.mp4"
	echo "  "$0" -c cookies.txt https://www.youtube.com/playlist?list=WL"
}

function cleanup() {
	local exit_code=$?
	if ! "${YT_NO_CLEANUP}" && [[ -n "${CURRENT_CACHE}" ]] && [[ -d "${CURRENT_CACHE}" ]]; then
		rm -rf "${CURRENT_CACHE}"
	fi
	if [[ -d "${YT_TEMP_DIR}" ]] && [[ -z "$(ls -A "${YT_TEMP_DIR}")" ]]; then
		rm -rf "${YT_TEMP_DIR}"
	fi
	exit "${exit_code}"
}
trap cleanup EXIT INT TERM

function error() {
	echo -e "❌ [ERROR] ${1:-}" >&2
	exit 1
}

function log() {
	echo "[INFO] ${1:-}"
}

function install_dependency() {
	local dependency="${1%%=*}"
	local pkg_manager="${2:-apt}"
	local pkg_name="${3:-${dependency}}"
	local sudo=""
	if ! command -v "${dependency}" &>/dev/null; then
		if ! "${INSTALL_DEPENDENCIES}"; then
			error "Dependency '${dependency}' is missing. Please install it manually or set INSTALL_DEPENDENCIES=true"
		fi
		log "Installing: ${dependency}..."
		[ "$(id -u)" -gt 0 ] && sudo="sudo"
		case "${pkg_manager}" in
			apt)
				if command -v apt-get &>/dev/null; then
					${sudo} apt-get update -qq && ${sudo} apt-get install -y "${pkg_name}" >/dev/null
				else
					error "apt-get not found. Cannot auto-install '${dependency}'. Please install it manually."
				fi
			;;
			pip)
				if ! command -v pip &>/dev/null && ! command -v pip3 &>/dev/null; then
					install_dependency "pip" "apt" "python3-pip"
				fi
				python3 -m pip install --quiet --break-system-packages "${pkg_name}"
			;;
			npm)
				if ! command -v npm &>/dev/null; then
					install_dependency "npm"
				fi
				${sudo} npm install -g "${pkg_name}" >/dev/null
			;;
		esac
	fi
}

function check_dependencies() {
	log "Checking base dependencies..."
	install_dependency "ffmpeg"
	install_dependency "python3"
	install_dependency "yt-dlp" "pip"
	install_dependency "vot-cli" "npm" "https://github.com/alex2844/vot-cli/tarball/yandexdisk"
}

function get_clean_filename() {
	local url="$1"
	yt-dlp "${YTDLP_OPTS[@]}" --restrict-filenames --print filename -o "%(title)s.%(ext)s" "${url}"
}

function xml_escape() {
	local s="$1"
	s="${s//&/&amp;}"
	s="${s//</&lt;}"
	s="${s//>/&gt;}"
	echo "${s//\"/&quot;}"
}

function translate_video() {
	local url="$1"
	local local_file="${2:-}"
	local playlist_index="${3:-1}"
	local playlist_title="${4:-}"
	local from_lang="${YT_FROMLANG}"
	local to_lang="${YT_TOLANG}"
	
	local need_translation=true
	if [[ "${from_lang}" == "${to_lang}" ]]; then
		need_translation=false
		log "Languages match (${from_lang}). Translation step will be SKIPPED."
	fi

	local height=""
	if [[ "${YT_HEIGHT}" =~ ^[0-9]+$ ]] && [[ "${YT_HEIGHT}" -gt 0 ]]; then
		height="[height<=${YT_HEIGHT}]"
	fi
	local audio_format="bestaudio/best"
	local video_format="bestvideo${height}/best${height}"
	"${YT_FORCE_AVC}" && video_format="bestvideo[vcodec^=avc]${height}/best[vcodec^=avc]${height}/${video_format}"

	local filename
	if [[ -n "${local_file}" ]] && [[ -f "${local_file}" ]]; then
		filename=$(basename "${local_file}")
	else
		if ! filename=$(get_clean_filename "${url}"); then
			error "Failed to get filename."
			return
		fi
	fi
	local title=$(basename "${filename}" | sed -E 's/\.+\.([^.]+)$/.\1/' | sed -E "s/(\.[a-zA-Z0-9]+)+$//")
	local final_file="${YT_OUTPUT_DIR}/${title}.${YT_OUTPUT_EXT}"
	
	if [[ -f "${final_file}" ]]; then
		log "File exists: ${final_file}. Skipping."
		return
	fi

	log "Processing: ${title}"

	local cache="${YT_TEMP_DIR}/${title}"
	CURRENT_CACHE="${cache}"
	mkdir -p "${cache}"

	if "${need_translation}" && [[ ! -f "${cache}/audio_translated.mp3" ]]; then
		log "Downloading translation..."
		local translate_ok=true
		vot-cli --lang="${from_lang}" --reslang="${to_lang}" --output="${cache}" --output-file="audio_translated.mp3" "${url}" >/dev/null || translate_ok=false
		if ! "${translate_ok}" || [[ ! -f "${cache}/audio_translated.mp3" ]]; then
			error "VOT-CLI failed to get translation."
		fi
	fi

	local video_input=""
	local audio_input=""
	if [[ -n "${local_file}" ]] && [[ -f "${local_file}" ]]; then
		log "Using LOCAL file as source: ${local_file}"
		video_input="${local_file}"
		audio_input="${local_file}"
	else
		log "Downloading streams..."
		video_input=$(find "${cache}" -name "video.*" -type f | head -n 1)
		if [[ -z "${video_input}" ]]; then
			local video_dlp_opts=("${YTDLP_OPTS[@]}")
			"${YT_SPONSORBLOCK}" && video_dlp_opts+=(--sponsorblock-mark all)
			if ! yt-dlp "${video_dlp_opts[@]}" --progress -f "${video_format}" -o "${cache}/video.%(ext)s" "${url}"; then
				error "Video download failed."
			fi
			video_input=$(find "${cache}" -name "video.*" -type f | head -n 1)
		fi

		audio_input=$(find "${cache}" -name "audio.*" -type f | head -n 1)
		if [[ -z "${audio_input}" ]]; then
			if ffprobe -v error -select_streams a -show_entries stream=codec_type "${video_input}" 2>/dev/null | grep -q "audio"; then
				audio_input="${video_input}"
			else
				if ! yt-dlp "${YTDLP_OPTS[@]}" --progress -f "${audio_format}" -o "${cache}/audio.%(ext)s" "${url}"; then
					error "Audio download failed."
				fi
				audio_input=$(find "${cache}" -name "audio.*" -type f | head -n 1)
			fi
		fi
		if "${YT_GENERATE_META}"; then
			if [[ ! -f "${cache}/meta.jpg" ]] || [[ ! -f "${cache}/meta.nfo" ]]; then
				log "Fetching metadata (NFO/JPG)..."
				local meta_data=$(yt-dlp "${YTDLP_OPTS[@]}" \
					--no-simulate --skip-download --write-thumbnail --convert-thumbnails jpg --output "${cache}/meta" \
					--print id --print upload_date --print duration --print uploader --print title --print "categories" --print "tags" --print description \
					"${url}")
				if [[ -n "${meta_data}" ]]; then
					mapfile -t d <<< "${meta_data}"
					local video_id="${d[0]}"
					local date="${d[1]}"
					local duration="${d[2]}"
					local uploader=$(xml_escape "${d[3]}")
					local title=$(xml_escape "${d[4]}")
					local categories_raw="${d[5]}"
					local tags_raw="${d[6]}"
					local desc=$(xml_escape "$(printf "%s\n" "${d[@]:7}")")

					local kodi_date=""
					[[ "${date}" =~ ^[0-9]{8}$ ]] && kodi_date="${date:0:4}-${date:4:2}-${date:6:2}"

					local genre_cleaned="${categories_raw//\'/}"
					genre_cleaned="${genre_cleaned//[/}"
					genre_cleaned="${genre_cleaned//]/}"
					local genre=$(xml_escape "${genre_cleaned%%,*}")

					local tags_xml=""
					local tags="${tags_raw#[}"
					tags="${tags%]}"
					if [[ -n "${tags}" ]]; then
						while IFS= read -r tag; do
							local tag_cleaned=$(echo "${tag}" | xargs)
							if [[ -n "${tag_cleaned}" ]]; then
								tags_xml+="<tag>$(xml_escape "$tag_cleaned")</tag>"
							fi
						done <<< "${tags//,/$'\n'}"
					fi

					sed 's/^> //' <<-EOF | tee "${cache}/meta.nfo" > /dev/null
						> <?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
						> <musicvideo>
						>     <uniqueid type="youtube" default="true">${video_id}</uniqueid>
						>     <studio>YouTube</studio>
						>     ${playlist_title:+"<album>$(xml_escape "${playlist_title}")</album>"}
						>     ${playlist_index:+"<track>${playlist_index}</track>"}
						>     <title>${title%.}</title>
						>     <artist>${uploader}</artist>
						>     <plot>${desc}</plot>
						>     <year>${date:0:4}</year>
						>     <premiered>${kodi_date}</premiered>
						>     <genre>${genre}</genre>
						>     ${tags_xml}
						>     <fileinfo>
						>         <streamdetails>
						>             <video>
						>                 <durationinseconds>${duration:-0}</durationinseconds>
						>             </video>
						>         </streamdetails>
						>     </fileinfo>
						> </musicvideo>
					EOF
				fi
			fi
		fi
	fi

	local mixed_audio="${cache}/mixed_final.mp3"
	if [[ ! -f "${mixed_audio}" ]]; then
		if ! "${need_translation}"; then
			log "Skipping mix (original audio only), converting to MP3..."
			ffmpeg -y -hide_banner -loglevel warning -stats \
				-i "${audio_input}" \
				-c:a libmp3lame -q:a 2 \
				-vn "${mixed_audio}"
		else
			log "Mixing to MP3 (Fast & Compatible)..."
			ffmpeg -y -hide_banner -loglevel warning -stats \
				-i "${audio_input}" \
				-i "${cache}/audio_translated.mp3" \
				-filter_complex \
				"[0:a]volume=${YT_ORIG_VOLUME}[orig];[1:a]volume=1.8[trans];[orig][trans]amix=inputs=2:duration=first[aout]" \
				-map "[aout]" \
				-c:a libmp3lame -q:a 2 \
				-ac 2 \
				-vn \
				"${mixed_audio}"
		fi
	fi

	log "Muxing Video + MP3 Audio..."
	local mux_ok=true
	ffmpeg -y -hide_banner -loglevel warning -stats \
		-fflags +genpts \
		-i "${video_input}" \
		-i "${mixed_audio}" \
		-map 0:v -map 1:a \
		-c:v copy -c:a copy \
		"${final_file}" || mux_ok=false
	if "${mux_ok}" && [[ -f "${final_file}" ]]; then
		log "Done: ${final_file}"
		if "${YT_GENERATE_META}"; then
			[[ -f "${cache}/meta.nfo" ]] && cp "${cache}/meta.nfo" "${final_file}.nfo"
			[[ -f "${cache}/meta.jpg" ]] && cp "${cache}/meta.jpg" "${final_file}-thumb.jpg"
			[[ -f "${cache}/meta.jpg" ]] && cp "${cache}/meta.jpg" "${final_file}-fanart.jpg"
		fi
		if "${YT_MARK_WATCHED}" && [[ -n "${YT_COOKIES}" ]]; then
			log "Marking video as watched on YouTube..."
			yt-dlp "${YTDLP_OPTS[@]}" --mark-watched --skip-download "${url}" >/dev/null 2>&1 || log "⚠️ Could not mark video as watched."
		fi
		if ! "${YT_NO_CLEANUP}"; then
			rm -rf "${cache}"
		fi
		CURRENT_CACHE=""
	else
		error "Muxing failed."
	fi
}

function main() {
	if [[ $# -gt 0 ]]; then
		local OPTIONS="hv4r:f:t:c:o:"
		local LONGOPTS="help,version,ipv4,height:,from_lang:,to_lang:,cookies:,output:,temp-dir:,force-avc,mark-watched,no-cleanup,meta,no-sponsorblock"
		eval set -- $(getopt --options="${OPTIONS}" --longoptions="${LONGOPTS}" --name "$0" -- "$@")
		while getopts "${OPTIONS}-:" OPT; do
			if [[ "${OPT}" = "-" ]]; then
				OPT="${OPTARG}"
				OPTARG=""
				if [[ "${LONGOPTS}" =~ (^|,)${OPT}: ]]; then
					OPTARG="${!OPTIND}"
					((OPTIND++))
				fi
			fi
			case "${OPT}" in
				h|help)
					usage;
					exit 0
				;;
				v|version)
					echo "${VERSION}";
					exit 0
				;;
				4|ipv4) YT_FORCE_IPV4=true;;
				r|height) YT_HEIGHT="${OPTARG}";;
				f|from_lang) YT_FROMLANG="${OPTARG}";;
				t|to_lang) YT_TOLANG="${OPTARG}";;
				c|cookies) YT_COOKIES="${OPTARG}";;
				o|output) YT_OUTPUT_DIR="${OPTARG}";;
				temp-dir) YT_TEMP_DIR="${OPTARG}";;
				force-avc) YT_FORCE_AVC=true;;
				mark-watched) YT_MARK_WATCHED=true;;
				meta) YT_GENERATE_META=true;;
				no-cleanup) YT_NO_CLEANUP=true;;
				no-sponsorblock) YT_SPONSORBLOCK=false;;
			esac
		done
		shift $((OPTIND - 1))
		[[ -n "${1:-}" ]] && YT_URL="$1"
		[[ -n "${2:-}" ]] && YT_LOCAL_PATH="$2"
	fi
	if [[ -z "${YT_URL}" ]]; then
		if [[ -n "${COLAB_RELEASE_TAG:-}" ]]; then
			error "URL or File not specified."
		else
			error "URL not specified."
		fi
	fi

	"${YT_FORCE_IPV4}" && YTDLP_OPTS+=(--force-ipv4)
	[[ -n "${YT_COOKIES}" ]] && YTDLP_OPTS+=(--cookies "${YT_COOKIES}")

	check_dependencies
	mkdir -p "${YT_OUTPUT_DIR}" "${YT_TEMP_DIR}"

	if [[ -n "${COLAB_RELEASE_TAG:-}" ]] && [[ "${YT_URL}" != *"://"* ]] && [[ "${YT_URL}" == *"/MyDrive/"* ]]; then
		YT_LOCAL_PATH="${YT_URL}"
		[[ ! -f "${YT_LOCAL_PATH}" ]] && error "File not found: ${YT_LOCAL_PATH}"
		install_dependency "xattr"
		local fileid=$(xattr -p 'user.drive.id' "${YT_LOCAL_PATH}" 2>/dev/null)
		[[ -z "${fileid:-}" ]] && error "File not found: ${YT_LOCAL_PATH}"
		YT_URL="https://drive.google.com/file/d/${fileid}/view"
	fi

	if [[ -n "${YT_LOCAL_PATH}" ]]; then
		[[ ! -f "${YT_LOCAL_PATH}" ]] && error "Local file not found: ${YT_LOCAL_PATH}"
		log "Single file mode (Local Source)"
		translate_video "${YT_URL}" "${YT_LOCAL_PATH}"
	else
		log "Fetching video list..."
		local playlist_title=""
		local urls=()
		if [[ "${YT_URL}" == *"youtube.com"* ]] || [[ "${YT_URL}" == *"youtu.be"* ]]; then
			if "${YT_GENERATE_META}" && [[ "${YT_URL}" == *"list="* ]]; then
				log "Playlist detected. Fetching title..."
				playlist_title=$(yt-dlp "${YTDLP_OPTS[@]}" --print playlist_title -I 1 "${YT_URL}")
				[[ "${playlist_title}" == "NA" ]] && playlist_title=""
				[[ -n "$playlist_title" ]] && log "Playlist title found: ${playlist_title}"
			fi
			while IFS= read -r video_id; do
				if [[ -n "${video_id}" ]] && [[ "${video_id}" != "NA" ]]; then
					urls+=("https://youtu.be/${video_id}")
				fi
			done < <(yt-dlp "${YTDLP_OPTS[@]}" --flat-playlist --print id --ignore-errors "${YT_URL}")
		else
			urls+=("${YT_URL}")
		fi
		local count=1
		local total=${#urls[@]}
		[[ ${total} -eq 0 ]] && error "No videos found."
		for video_url in "${urls[@]}"; do
			log "=== [${count}/${total}] Processing ==="
			translate_video "${video_url}" "" "${count}" "${playlist_title}"
			((count++))
		done
	fi
	log "All completed."
}

if [[ "${BASH_SOURCE:-${0}}" == "${0}" ]]; then
	[[ -f ".env" ]] && source ".env"
	main "$@"
fi
