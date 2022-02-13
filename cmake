#!/bin/bash
# A wrapper that runs cmake within the make.sh environment
set -eo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cmd=$(basename "${BASH_SOURCE[0]}")
# FIXME see the if [ "$PROJECT" = monohack ] hack in make.sh
exec $DIR/build-env $DIR/make.sh monohack $cmd "$@"
