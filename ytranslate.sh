#!/usr/bin/env bash
set -euo pipefail
trap handle_exit EXIT

__file="$(basename $0)"

VERSION='1.0.1'
HELP="
Usage: ${__file} [OPTION...] <URL>
Options:
	-h, --help                  Show help options
	-v, --version               Show version information
	-r, --height=<int>          Set height
	-f, --from_lang=<str>       Set from language (en, ru, zh, ko, ar, fr, it, es, de, ja)
	-t, --to_lang=<str>         Set to language (ru, en, kk)
	-c, --cookies=<path>        Set path to cookies file
Set INSTALL_DEPENDENCIES=1 for automatic install dependencies.
"

handle_exit() {
	echo "[INFO] Exiting script, cleaning up temp files..."
	rm -rf ".ytranslate" "pretrained_models"
}

install_dependency() {
	local pkg="${2:-apt}"
	local dependency="${1%%=*}"
	local dependencies="${dependency}"
	local arg=''
	[[ -n "${3:-}" ]] && dependencies="${dependencies} ${3}"

	if ! command -v "${dependency}" &>/dev/null; then
		echo "[INFO] Installing missing dependency: ${dependency}"
		if [[ "${INSTALL_DEPENDENCIES:-0}" == "1" ]] || [[ -n "${COLAB_RELEASE_TAG:-}" ]]; then
			if [ $(id -u) -ne 0 ]; then
				echo "[ERROR] access denied (root required for install: ${dependency})"
				exit 1
			fi
			if [[ "${pkg}" == "apt" ]]; then
				arg='-y'
			elif [[ "${pkg}" == "pip" ]]; then
				if ! command -v "${pkg}" &>/dev/null; then
					echo "[INFO] pip not found, attempting to install pip"
					install_dependency "pip"
				fi
			elif [[ "${pkg}" == "npm" ]]; then
				if ! command -v "${pkg}" &>/dev/null; then
					echo "[INFO] npm not found, attempting to install Node.js"
					curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n | bash -s install lts
				fi
				arg='-g'
			fi
			if ! "${pkg}" install ${arg} ${dependencies}; then
				echo "[ERROR] ${dependency}: install failed"
				exit 1
			fi
		else
			echo "[ERROR] ${dependency} not found and auto-install disabled"
			exit 1
		fi
	fi
	if [[ "${dependency}" =~ ^python ]] && ([[ "${INSTALL_DEPENDENCIES:-0}" == "1" ]] || [[ -n "${COLAB_RELEASE_TAG:-}" ]]); then
		if [[ ! $(python3 -V 2>&1 | awk '{print $2}') =~ ^"${dependency:6}" ]]; then
			echo "[INFO] Updating python3 alternatives to ${dependency}"
			update-alternatives --set python3 "$(which ${dependency})"
			apt install -y python3-pip
		fi
	fi
}

echo "[INFO] Script started"

if (( $# > 0 )); then
	while getopts hvr:-:f:-:t:-:c:-: OPT; do
		if [ "${OPT}" = "-" ]; then
			OPT="${OPTARG%%=*}"
			OPTARG="${OPTARG#"$OPT"}"
			OPTARG="${OPTARG#=}"
		fi
		case "$OPT" in
			h | help )
				echo "${HELP:1}"
				exit
			;;
			v | version )
				echo "${VERSION}"
				exit
			;;
			r | height )
				HEIGHT="${OPTARG}"
				echo "[INFO] Video height set to: ${HEIGHT}"
			;;
			f | from_lang )
				FROMLANG="${OPTARG}"
				echo "[INFO] Source language set to: ${FROMLANG}"
			;;
			t | to_lang )
				TOLANG="${OPTARG}"
				echo "[INFO] Target language set to: ${TOLANG}"
			;;
			c | cookies )
				COOKIES="${OPTARG}"
			;;
		esac
	done
	shift $((OPTIND - 1))
	if (( $# > 0 )); then
		URL="$1"
		echo "[INFO] URL set to: ${URL}"
	fi
fi
if [[ -z "${URL:-}" ]]; then
	echo "[ERROR] URL not specified"
	echo "${HELP:1}" | head -n 1
	exit 1
fi

echo "[INFO] Checking and installing dependencies..."
install_dependency "ffmpeg"
install_dependency "python3.10"
install_dependency "spleeter" "pip" "numpy==1.26.4"
install_dependency "yt-dlp" "pip"
install_dependency "vot-cli" "npm"

COOKIE_ARGS=""
if [[ -n "${COOKIES:-}" ]] && [[ -f "${COOKIES}" ]]; then
	COOKIE_ARGS="--cookies ${COOKIES}"
fi

if [[ "${URL}" != *"://"* ]] && [[ "${URL}" == *"/MyDrive/"* ]] && [[ -n "${COLAB_RELEASE_TAG:-}" ]]; then
	echo "[INFO] Google Drive file detected, extracting file ID"
	install_dependency "xattr"
	filepath="${URL}"
	filename=$(basename "${filepath}")
	fileid=$(xattr -p 'user.drive.id' "${URL}")
	URL="https://drive.google.com/file/d/${fileid}/view"
	echo "[INFO] Updated Google Drive URL: ${URL}"
else
	if [[ "${URL}" =~ ^(https?://)?((www.|m.)?youtube(-nocookie)?.com)|(youtu.be) ]]; then
		audio_format="bestaudio[ext=m4a]"
		video_format="bestvideo[ext=mp4]"
		[[ "${HEIGHT:-0}" != "0" ]] && video_format="${video_format}[height<=${HEIGHT}]"
		echo "[INFO] YouTube video detected, using formats: audio='${audio_format}', video='${video_format}'"
	fi
	unset filepath
	echo "[INFO] Getting output filename from yt-dlp..."
	filename=$(yt-dlp ${COOKIE_ARGS} --print filename -o "%(title)s.%(ext)s" "${URL}" \
           | sed 's/[^a-zA-Z0-9._-]/-/g')
	echo "[INFO] Download filename: ${filename}"
fi
if [[ -z "${filename}" ]]; then
	echo "[ERROR] file not found"
	exit 1
fi
title=$(echo "${filename}" | sed -E "s/(\.${filename##*.})+$//" | sed 's/--*/-/g' | sed -E 's/(^-|-$)//g' | tr ' ' '_')
if [[ -f "${title}.mp4" ]]; then
	echo "[INFO] File '${title}.mp4' already exists. Exiting."
	exit 0
fi

cache=".ytranslate/${title}"
mkdir -p "${cache}"
echo "[INFO] Cache directory created: ${cache}"

if [[ ! -f "${cache}/audio.mp3" ]]; then
	echo "[INFO] Downloading translated audio with vot-cli..."
	if ! vot-cli \
		--lang="${FROMLANG:-en}" --reslang="${TOLANG:-ru}" \
		--output="${cache}" --output-file="audio.mp3" "${URL}" >/dev/null || [[ ! -f "${cache}/audio.mp3" ]];
	then
		echo "[ERROR] vot-cli failed to download audio."
		exit 1
	fi
fi
if [[ ! -f "${cache}/audio.m4a" ]] || [[ ! -f "${cache}/video.mp4" ]]; then
	if [[ -n "${audio_format:-}" ]] && [[ -n "${video_format:-}" ]]; then
		if [[ ! -f "${cache}/audio.m4a" ]]; then
			echo "[INFO] Downloading audio (m4a) with yt-dlp..."
			if ! yt-dlp ${COOKIE_ARGS} -f "${audio_format}" -o "${cache}/audio.m4a" "${URL}" || [[ ! -f "${cache}/audio.m4a" ]]; then
				echo "[ERROR] yt-dlp failed to download audio."
				exit 1
			fi
		fi
		if [[ ! -f "${cache}/video.mp4" ]]; then
			echo "[INFO] Downloading video (mp4) with yt-dlp..."
			if ! yt-dlp ${COOKIE_ARGS} -f "${video_format}" -o "${cache}/video.mp4" "${URL}" || [[ ! -f "${cache}/video.mp4" ]]; then
				echo "[ERROR] yt-dlp failed to download video."
				exit 1
			fi
		fi
	else
		if [[ -z "${filepath:-}" ]]; then
			if [[ ! -f "${cache}/${filename}" ]]; then
				echo "[INFO] Downloading combined audio+video with yt-dlp..."
				if ! yt-dlp ${COOKIE_ARGS} -o "${cache}/${filename}" "${URL}" || [[ ! -f "${cache}/${filename}" ]]; then
					echo "[ERROR] yt-dlp failed to download audio+video."
					exit 1
				fi
			fi
			filepath="${cache}/${filename}"
		fi
		echo "[INFO] Splitting audio and video using ffmpeg..."
		ffmpeg -i "${filepath}" -vn -acodec copy "${cache}/audio.m4a" -an -vcodec copy "${cache}/video.mp4" -nostdin
	fi
fi
if [[ ! -f "${cache}/audio/vocals.wav" ]] || [[ ! -f "${cache}/audio/accompaniment.wav" ]]; then
	echo "[INFO] Running spleeter for source separation..."
	if ! spleeter separate -o "${cache}" "${cache}/audio.m4a"; then
		echo "[ERROR] spleeter failed."
		exit 1
	fi
fi
echo "[INFO] Mixing translated vocals and instrumental to video..."
if ! ffmpeg \
	-i "${cache}/video.mp4" \
	-i "${cache}/audio.mp3" \
	-i "${cache}/audio/accompaniment.wav" \
	-map 0:v \
	-filter_complex "[1:a][2:a]amix=inputs=2:duration=longest[a]" \
	-map "[a]" \
	-c:v copy \
	-c:a aac -strict experimental -nostdin \
	"${title}.mp4" || [[ ! -f "${title}.mp4" ]];
then
	echo "[ERROR] ffmpeg failed"
	exit 1
fi

echo "[INFO] Script completed successfully! Output: ${title}.mp4"
