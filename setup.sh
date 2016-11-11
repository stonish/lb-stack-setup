export CCACHE_DIR=${PWD}/.ccache
export CMAKEFLAGS=-DCMAKE_USE_CCACHE=ON
export CMAKE_PREFIX_PATH=${PWD}:/cvmfs/sft.cern.ch/lcg/releases:${CMAKE_PREFIX_PATH}
export VERBOSE=
export PATH=${PATH}:/cvmfs/lhcb.cern.ch/lib/contrib/ninja/1.4.0/x86_64-slc6
