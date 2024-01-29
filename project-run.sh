#!/bin/bash
self=$(LC_ALL=C find $0 -type l -printf '%l\n')
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
exec $(dirname $self)/run-env $(basename "$DIR") "$@"
