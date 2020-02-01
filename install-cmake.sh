#!/bin/bash
set -eo pipefail

. $(dirname $0)/install-common.sh

mkdir -p ${CONTRIB}/bin
touch ${CONTRIB}/bin/.cmake_timestamp  # because Makefile uses the symlink target mtime
ln -sf /cvmfs/lhcb.cern.ch/lib/contrib/CMake/3.16.2/Linux-x86_64/bin/cmake ${CONTRIB}/bin

# curl -Lo "$SRC_BASE/cmake.tar.gz" \
#     https://github.com/Kitware/CMake/releases/download/v3.15.1/cmake-3.15.1-Linux-x86_64.tar.gz
# mkdir -p ${CONTRIB}
# tar -xzf "$SRC_BASE/cmake.tar.gz" --strip-components 1 -C "$CONTRIB" -m
# rm "$SRC_BASE/cmake.tar.gz"
