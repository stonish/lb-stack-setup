script="
set -xeo pipefail

ls /cvmfs/{lhcb,lhcb-condb,lhcbdev,sft}.cern.ch/

klist

git --version
"

utils/build-env bash -c "$script"
exit_code=$?
if [ $exit_code -ne 0 ]; then
    echo "ERROR   There is a problem with the build environment (exit code $exit_code)" >&2
    echo "ERROR   Check output above" >&2
    exit 1
fi
