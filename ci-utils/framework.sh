# the equivalent of "pragma once"
declare -A already_evaled
[[ ${already_evaled["framework"]-} ]] && return
already_evaled["framework"]=1

set -xo pipefail

_retcode=0
_problems=

error() {
    _problems+="ERROR $1\n"
    _retcode=1
}

_report() {
    echo -en $_problems >&2
    exit $_retcode
}
trap _report EXIT
