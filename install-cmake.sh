#!/bin/bash
set -eo pipefail

. $(dirname $0)/install-common.sh

setup 'https://gitlab.kitware.com/rmatev/cmake.git' 'master-5a2023f904-lhcb'
(
    cmake "-DCMAKE_INSTALL_PREFIX:PATH=$CONTRIB" .
    make install -j$(nproc)
)
cleanup
