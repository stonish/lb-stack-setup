#!/bin/bash
set -eo pipefail

DIR=$(dirname $0)

"${DIR}/build-env" bash -c "
bash '$DIR/install-cmake.sh'
bash '$DIR/install-ninja.sh'
bash '$DIR/install-ccache.sh'
bash '$DIR/install-distcc.sh'
"

bash "$DIR/install-tools.sh"

# test that everything was installed ok
ls cmake ninja ccache distcc pump ninjatracing post_build_ninja_summary.py
