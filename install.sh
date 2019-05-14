#!/bin/bash

LOCAL_TOOLS=`pwd`/tools

git submodule update --init --recursive --depth 1

pushd tools/src/ninja
./configure.py --bootstrap
cp ninja $LOCAL_TOOLS/bin
popd

pushd tools/src/ccache
# sudo yum -y install gperf
./autogen.sh
./configure --prefix $LOCAL_TOOLS --disable-man
make install
popd

pushd tools/src/distcc
./autogen.sh
./configure --prefix $LOCAL_TOOLS --with-auth
make install
popd

# git submodule add -b ninja-pool-custom-command https://gitlab.kitware.com/rmatev/cmake.git tools/src/cmake
pushd tools/src/cmake
bash -c ". /cvmfs/sft.cern.ch/lcg/views/LCG_95/x86_64-centos7-gcc8-opt/setup.sh ; cmake -DCMAKE_INSTALL_PREFIX:PATH=$LOCAL_TOOLS . ; make -j$(nproc) ; make install "
popd

https://cs.chromium.org/codesearch/f/chromium/tools/depot_tools/post_build_ninja_summary.py

