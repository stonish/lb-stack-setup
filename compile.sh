#!/bin/bash

# if compiler is not on cvmfs, ignore distcc
if [[ "$1" != "/cvmfs"* ]]; then
    if [[ "$COMPILER_PREFIX" == *"distcc" ]]; then
        unset COMPILER_PREFIX
        echo Cannot use distcc with $1 >&2
    elif [[ "$CCACHE_PREFIX" == *"distcc" ]]; then
        unset CCACHE_PREFIX
        echo Cannot use distcc with $1 >&2
    fi
fi

args=()
[ -n "$COMPILER_PREFIX" ] && args+=("$COMPILER_PREFIX")
args+=("$@")
exec "${args[@]}"
