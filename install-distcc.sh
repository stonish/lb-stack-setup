#!/bin/bash
set -eo pipefail

. $(dirname $0)/install-common.sh

setup 'https://github.com/rmatev/distcc.git' 'master-76d8dc6-lhcb'
(
    . /cvmfs/sft.cern.ch/lcg/views/LCG_95apython3/x86_64-centos7-gcc8-opt/setup.sh
    ./autogen.sh
    ./configure --prefix $CONTRIB --with-auth --without-libiberty
    make install -j$(nproc)
)
cleanup
