#!/bin/bash
set -eo pipefail

. $(dirname $0)/install-common.sh

setup 'https://github.com/rmatev/distcc.git' '4387788e198a372812da66b91de8f303ba65d940'
(
    . /cvmfs/sft.cern.ch/lcg/views/LCG_96bpython3/x86_64-centos7-gcc9-opt/setup.sh
    ./autogen.sh
    ./configure --prefix $CONTRIB --with-auth --without-libiberty
    make install -j$(nproc)
)
cleanup
