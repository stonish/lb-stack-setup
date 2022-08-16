#!/bin/bash
# A wrapper that runs cmake within the make.sh environment.
# This is needed because
#   1. we don't want to replicate the env var setup from make.sh in the CMakePresets
#   2. we can't replicate e.g. distcc pump startup and build output postprocessing.

set -eo pipefail
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cmd=$(basename "${BASH_SOURCE[0]}")
# FIXME see the if [ "$PROJECT" = monohack ] hack in make.sh
exec $DIR/build-env $DIR/make.sh monohack $cmd "$@"
