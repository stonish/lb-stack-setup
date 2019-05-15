#!/bin/bash

. $(dirname $0)/install-common.sh

curl -o "${CONTRIB}/bin/post_build_ninja_summary.py" \
    "https://cs.chromium.org/codesearch/f/chromium/tools/depot_tools/post_build_ninja_summary.py?cl=2d3b9260f3085f0ce161dbec51f131979b828474"
chmod +x "${CONTRIB}/bin/post_build_ninja_summary.py"

curl -o "${CONTRIB}/bin/ninjatracing" \
    https://raw.githubusercontent.com/nico/ninjatracing/37e79ec0e570d08efaabfea10f3dcf8e4ad519f8/ninjatracing
chmod +x "${CONTRIB}/bin/ninjatracing"