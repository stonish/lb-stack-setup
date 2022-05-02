#!/bin/bash
self=$(target=$0 perl -le 'print readlink $ENV{target}')
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
# assume that utils ($DIR) is under $LBENV_CURRENT_WORKSPACE/$projectPath
projectPath=$(dirname $DIR)
exec $(dirname $self)/run-env $(basename "$DIR") \
    gdb -iex "directory ${projectPath}" -ix "$DIR/gdbinit" "$@"
