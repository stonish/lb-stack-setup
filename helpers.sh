_helpers_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

config() { "${_helpers_dir}/config.py" "$@"; }

gitc() { pushd "$1" >/dev/null && git "${@:2}" && popd >/dev/null; }

log() {
    if [ "$level" != DEBUG ]; then
        printf "%-8s %s\n" "$1" "$2" >&2
    fi
    local ts=
    if [[ "$OSTYPE" == "linux-gnu" ]]; then
        printf -v ts '%(%FT%T    )T\n' -1
    else
        ts=$(date "+%Y-%m-%dT%H:%M:%S    ")
    fi
    printf "%s %-15s %-8s %s\n" "$ts" "${logname:-bash}" "$1" "$2" >> "$LOG_FILE"
}

OUTPUT="$(config outputPath)"
LOG_FILE="$OUTPUT/log"
mkdir -p "$OUTPUT"

# TODO log *everything* with https://askubuntu.com/a/1001404/417217
