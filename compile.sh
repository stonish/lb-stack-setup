#!/bin/bash
if [ -n "$COMPILER_PREFIX" ]; then
    "$COMPILER_PREFIX" "$@"
else
    "$@"
fi
