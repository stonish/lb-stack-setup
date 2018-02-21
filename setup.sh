#!/bin/bash
set -e
export CCACHE_DIR=${PWD}/.ccache
export CCACHE_TEMPDIR=${XDG_RUNTIME_DIR:-$(dirname $(mktemp -u))/$(id -u)}/ccache-tmp  # use a faster TMPDIR
mkdir -p ${CCACHE_TEMPDIR}
export CCACHE_NOCPP2=1  # compile the preprocessed source on cache miss; faster but possibly different diagnostic warnings
#export CCACHE_LOGFILE=$(dirname $(mktemp -u))/ccache.debug
export CMAKEFLAGS="-DCMAKE_USE_CCACHE=ON -DLOKI_BUILD_FUNCTOR_CACHE=FALSE --no-warn-unused-cli"
export CMAKE_PREFIX_PATH=${PWD}:${CMAKE_PREFIX_PATH}
export VERBOSE=
export PATH=${PATH}:/cvmfs/lhcb.cern.ch/lib/contrib/ninja/1.4.0/x86_64-slc6

# Tweaks for LXPLUS
if [[ $(hostname) == lxplus* ]]; then
  # don't be too aggressive or else g++ gets killed
  export NINJAFLAGS=-j6
fi
