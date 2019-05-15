#!/bin/bash

. $(dirname $0)/install-common.sh

setup 'https://gitlab.kitware.com/rmatev/cmake.git' 'master-5a2023f904-lhcb'
(
    . /cvmfs/sft.cern.ch/lcg/views/LCG_95/x86_64-centos7-gcc8-opt/setup.sh
    cmake -DCMAKE_INSTALL_PREFIX:PATH=$CONTRIB .
    make install -j$(nproc)
)
cleanup