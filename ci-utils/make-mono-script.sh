set -euxo pipefail

PLATFORM=$(utils/config.py binaryTag)  # make sure we don't use BINARY_TAG or CMTCONFIG
MONO_BUILD_PATH=mono/build.$PLATFORM

utils/config.py  # print config
make configure
bash utils/ci-utils/test-cmake.sh $MONO_BUILD_PATH
make configure  # test a reconfigure
bash utils/ci-utils/test-cmake.sh $MONO_BUILD_PATH

bash utils/ci-utils/test-misc.sh

utils/stats
