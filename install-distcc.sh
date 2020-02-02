#!/bin/bash
set -eo pipefail

. $(dirname $0)/install-common.sh

setup 'https://github.com/rmatev/distcc.git' 'master-fd943af-lhcb'
(
    set +e  # disable immediate exit because of incompatibility with CentOS 8
    . /cvmfs/sft.cern.ch/lcg/views/LCG_96bpython3/x86_64-centos7-gcc9-opt/setup.sh
    set -e
    ./autogen.sh
    ./configure --prefix $CONTRIB --with-auth --without-libiberty
    make install -j$(nproc)
)
cleanup
