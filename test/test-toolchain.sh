script='
set -xeo pipefail
contrib/bin/cmake --version
contrib/bin/ninja --version
contrib/bin/ccache --version
contrib/bin/distcc --version

# TODO remove hardcoded python3 path?
PYTHON=/cvmfs/sft.cern.ch/lcg/releases/LCG_96bpython3/Python/3.6.5/x86_64-centos7-gcc9-opt/bin/python
include_server_install="contrib/lib/python3.6/site-packages/include_server"
# Do just a simple import as include_server does not have a --version flag
PYTHONPATH="$PYTHONPATH:$include_server_install" $PYTHON -c "import include_server"
'

utils/build-env bash -c "$script"
exit_code=$?
if [ $exit_code -ne 0 ]; then
    echo "ERROR   There is a problem with the build environment (exit code $exit_code)" >&2
    echo "ERROR   Check output above" >&2
    exit 1
fi
