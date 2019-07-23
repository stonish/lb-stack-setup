#!/bin/bash
set -eo pipefail

. $(dirname $0)/install-common.sh

# master on 10 May 2019
setup 'https://github.com/kitware/ninja.git' 'v1.9.0.g99df1.kitware.dyndep-1.jobserver-1'
(
    ./configure.py --bootstrap
    cp ninja "$CONTRIB/bin"
)
cleanup
