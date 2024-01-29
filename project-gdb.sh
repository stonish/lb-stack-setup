#!/bin/bash
self=$(LC_ALL=C find $0 -type l -printf '%l\n')
utils=$(dirname $self)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
projectPath=$(dirname $DIR)
exec $utils/run-env $(basename "$DIR") \
    gdb -iex "directory ${projectPath}" -ix "$utils/gdbinit" "$@"
