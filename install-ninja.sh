#!/bin/bash
set -eo pipefail

. $(dirname $0)/install-common.sh

curl -Lo "$SRC_BASE/ninja-linux.zip" \
    https://github.com/ninja-build/ninja/releases/download/v1.10.0/ninja-linux.zip
unzip -o -DD -d "$CONTRIB/bin" "$SRC_BASE/ninja-linux.zip"
rm "$SRC_BASE/ninja-linux.zip"
