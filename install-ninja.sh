#!/bin/bash
set -eo pipefail

. $(dirname $0)/install-common.sh

# master on 10 May 2019
setup 'https://github.com/ninja-build/ninja.git' '20b30dac6698d119e7797b34d6ed2c4ed8f48417'
(
    ./configure.py --bootstrap
    cp ninja "$CONTRIB/bin"
)
cleanup
