#!/bin/bash
set -eo pipefail

. $(dirname $0)/install-common.sh

# master on 11 May 2019
setup 'https://github.com/ccache/ccache.git' 'v3.7.12'
(
    set +e  # disable immediate exit because of incompatibility with CentOS 8
    . /cvmfs/sft.cern.ch/lcg/views/LCG_96b/x86_64-centos7-gcc9-opt/setup.sh
    set -e
    ./autogen.sh
    ./configure --prefix "$CONTRIB" --disable-man
    make install
)
cleanup