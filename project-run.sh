#!/bin/bash
self=$(LC_ALL=C target=$0 perl -le 'print readlink $ENV{target}')
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
exec $(dirname $self)/run-env $(basename "$DIR") "$@"
