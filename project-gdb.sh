#!/bin/bash
self=$(LC_ALL=C target=$0 perl -le 'print readlink $ENV{target}')
utils=$(dirname $self)
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
projectPath=$(dirname $DIR)
exec $utils/run-env $(basename "$DIR") \
    gdb -iex "directory ${projectPath}" -ix "$utils/gdbinit" "$@"
