set -euxo pipefail

binaryTag=$(utils/config.py binaryTag)
BINARY_TAG=${BINARY_TAG:-$binaryTag}
MONO_BUILD_PATH=$(utils/config.py buildPath)/mono/build.$BINARY_TAG

utils/config.py  # print config
make configure
bash utils/ci-utils/test-cmake.sh $MONO_BUILD_PATH
make configure  # test a reconfigure
bash utils/ci-utils/test-cmake.sh $MONO_BUILD_PATH

bash utils/ci-utils/test-misc.sh

utils/stats

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/framework.sh"

make purge
if [ -e $MONO_BUILD_PATH ]; then
    error "purge did not clean the build directory"
fi
make purge  # second purge should not fail
