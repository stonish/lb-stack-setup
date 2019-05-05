#!/bin/bash

LOCAL_TOOLS=`pwd`/tools

git submodule update --init --recursive

pushd tools/src/distcc
./autogen.sh
./configure --prefix $LOCAL_TOOLS --with-auth
make install
popd

pushd tools/src/ccache
# sudo yum -y install gperf
./autogen.sh
./configure --prefix $LOCAL_TOOLS --disable-man
make install
popd

pushd tools/src/ninja
./configure.py --bootstrap
cp ninja $LOCAL_TOOLS/bin
popd
