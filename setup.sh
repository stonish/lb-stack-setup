#!/bin/bash
export CCACHE_DIR=${PWD}/.ccache
#export CCACHE_LOGFILE=$(dirname $(mktemp -u))/ccache.debug
export CMAKEFLAGS="-DCMAKE_USE_CCACHE=ON -DLOKI_BUILD_FUNCTOR_CACHE=FALSE"
export CMAKE_PREFIX_PATH=${PWD}:${CMAKE_PREFIX_PATH}
export VERBOSE=
export PATH=${PATH}:/cvmfs/lhcb.cern.ch/lib/contrib/ninja/1.4.0/x86_64-slc6

# Tweaks for LXPLUS
if [[ $(hostname) == lxplus* ]]; then
  # use the faster TMPDIR
  export CCACHE_TEMPDIR=$(dirname $(mktemp -u))/ccache
  mkdir -p ${CCACHE_TEMPDIR}
  # don't be too aggressive or else g++ gets killed
  export NINJAFLAGS=-j6
fi