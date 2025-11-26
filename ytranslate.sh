#!/usr/bin/env bash
set -euo pipefail

readonly VERSION='2.0.0'
: "${COOKIES:=}"
: "${URL:=}"
: "${LOCAL_PATH=}"
: "${FROMLANG="en"}"
: "${TOLANG="ru"}"
: "${HEIGHT=0}"
: "${ORIG_VOLUME=0.15}"
: "${TEMP_DIR=".ytranslate"}"
: "${OUTPUT_EXT="mkv"}"
: "${OUTPUT_DIR="."}"
: "${NO_CLEANUP=false}"
: "${FORCE_IPV4=false}"

CURRENT_CACHE=""
YTDLP_OPTS=()
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
	if ! "${NO_CLEANUP}" && [[ -n "${CURRENT_CACHE}" ]] && [[ -d "${CURRENT_CACHE}" ]]; then
		rm -rf "${CURRENT_CACHE}"
	fi
	if [[ -d "${TEMP_DIR}" ]] && [[ -z "$(ls -A "${TEMP_DIR}")" ]]; then
		rm -rf "${TEMP_DIR}"
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

function translate_video() {
	local url="$1"
	local local_file="${2:-}"
	
	local need_translation=true
	if [[ "${FROMLANG}" == "${TOLANG}" ]]; then
		need_translation=false
		log "Languages match (${FROMLANG}). Translation step will be SKIPPED."
	fi

	local video_format="bestvideo[vcodec^=avc]/bestvideo"
	local audio_format="bestaudio"
	[[ "${HEIGHT:-0}" != "0" ]] && video_format="bestvideo[vcodec^=avc][height<=${HEIGHT}]/bestvideo[height<=${HEIGHT}]"

	local filename
	if [[ -n "${local_file}" ]] && [[ -f "${local_file}" ]]; then
		filename=$(basename "${local_file}")
	else
		if ! filename=$(get_clean_filename "${url}"); then
			error "Failed to get filename."
			return
		fi
	fi
	local title=$(basename "${filename}" | sed -E "s/(\.[a-zA-Z0-9]+)+$//")
	local final_file="${OUTPUT_DIR}/${title}.${OUTPUT_EXT}"
	
	if [[ -f "${final_file}" ]]; then
		log "File exists: ${final_file}. Skipping."
		return
	fi

	log "Processing: ${title}"

	local cache="${TEMP_DIR}/${title}"
	CURRENT_CACHE="${cache}"
	mkdir -p "${cache}"

	if "${need_translation}" && [[ ! -f "${cache}/audio_translated.mp3" ]]; then
		log "Downloading translation..."
		local translate_ok=true
		vot-cli --lang="${FROMLANG}" --reslang="${TOLANG}" --output="${cache}" --output-file="audio_translated.mp3" "${url}" >/dev/null || translate_ok=false
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
		if ! yt-dlp "${YTDLP_OPTS[@]}" --progress -f "${video_format}" -o "${cache}/video.%(ext)s" "${url}"; then
			error "Video download failed."
		fi
		if ! yt-dlp "${YTDLP_OPTS[@]}" --progress -f "${audio_format}" -o "${cache}/audio.%(ext)s" "${url}"; then
			error "Audio download failed."
		fi
		video_input=$(find "${cache}" -name "video.*" -type f | head -n 1)
		audio_input=$(find "${cache}" -name "audio.*" -type f | head -n 1)
	fi

	local mixed_audio="${cache}/mixed_final.mp3"
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
			"[0:a]volume=${ORIG_VOLUME}[orig];[1:a]volume=1.8[trans];[orig][trans]amix=inputs=2:duration=first[aout]" \
			-map "[aout]" \
			-c:a libmp3lame -q:a 2 \
			-ac 2 \
			-vn \
			"${mixed_audio}"
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
		if ! "${NO_CLEANUP}"; then
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
		local LONGOPTS="help,version,ipv4,height:,from_lang:,to_lang:,cookies:,output:,temp-dir:,no-cleanup"
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
				4|ipv4) FORCE_IPV4=true;;
				r|height) HEIGHT="${OPTARG}";;
				f|from_lang) FROMLANG="${OPTARG}";;
				t|to_lang) TOLANG="${OPTARG}";;
				c|cookies) COOKIES="${OPTARG}";;
				o|output) OUTPUT_DIR="${OPTARG}";;
				temp-dir) TEMP_DIR="${OPTARG}";;
				no-cleanup) NO_CLEANUP=true;;
			esac
		done
		shift $((OPTIND - 1))
		[[ -n "${1:-}" ]] && URL="$1"
		[[ -n "${2:-}" ]] && LOCAL_PATH="$2"
	fi
	if [[ -z "${URL}" ]]; then
		if [[ -n "${COLAB_RELEASE_TAG:-}" ]]; then
			error "URL or File not specified."
		else
			error "URL not specified."
		fi
	fi

	YTDLP_OPTS+=(--no-warnings)
	"${FORCE_IPV4}" && YTDLP_OPTS+=(--force-ipv4)
	[[ -n "${COOKIES}" ]] && YTDLP_OPTS+=(--cookies "${COOKIES}")
	
	check_dependencies
	mkdir -p "${OUTPUT_DIR}" "${TEMP_DIR}"

	if [[ -n "${COLAB_RELEASE_TAG:-}" ]] && [[ "${URL}" != *"://"* ]] && [[ "${URL}" == *"/MyDrive/"* ]]; then
		LOCAL_PATH="${URL}"
		[[ ! -f "${LOCAL_PATH}" ]] && error "File not found: ${LOCAL_PATH}"
		install_dependency "xattr"
		local fileid=$(xattr -p 'user.drive.id' "${LOCAL_PATH}" 2>/dev/null)
		[[ -z "${fileid:-}" ]] && error "File not found: ${LOCAL_PATH}"
		URL="https://drive.google.com/file/d/${fileid}/view"
	fi

	if [[ -n "${LOCAL_PATH}" ]]; then
		[[ ! -f "${LOCAL_PATH}" ]] && error "Local file not found: ${LOCAL_PATH}"
		log "Single file mode (Local Source)"
		translate_video "${URL}" "${LOCAL_PATH}"
	else
		log "Fetching video list..."
		local urls=()
		if [[ "${URL}" == *"youtube.com"* ]] || [[ "${URL}" == *"youtu.be"* ]]; then
			while IFS= read -r video_id; do
				if [[ -n "${video_id}" ]] && [[ "${video_id}" != "NA" ]]; then
					urls+=("https://youtu.be/${video_id}")
				fi
			done < <(yt-dlp "${YTDLP_OPTS[@]}" --flat-playlist --print id --ignore-errors "${URL}")
		else
			urls+=("${URL}")
		fi
		local count=1
		local total=${#urls[@]}
		[[ ${total} -eq 0 ]] && error "No videos found."
		for video_url in "${urls[@]}"; do
			log "=== [${count}/${total}] Processing ==="
			translate_video "${video_url}" ""
			((count++))
		done
	fi
	log "All completed."
}

if [[ "${BASH_SOURCE:-${0}}" == "${0}" ]]; then
	main "$@"
fi
