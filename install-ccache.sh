#!/bin/bash
set -eo pipefail

. $(dirname $0)/install-common.sh

# master on 11 May 2019
setup 'https://github.com/ccache/ccache.git' '6821579c2c2567415ed4d8a442e14860ab102f83'
(
    . /cvmfs/sft.cern.ch/lcg/views/LCG_95/x86_64-centos7-gcc8-opt/setup.sh
    ./autogen.sh
    ./configure --prefix "$CONTRIB" --disable-man
    make install
)
cleanup
