set -euxo pipefail

PLATFORM=$(utils/config.py binaryTag)  # make sure we don't use BINARY_TAG or CMTCONFIG

utils/config.py  # print config
make Gaudi/configure
bash utils/ci-utils/test-cmake.sh Gaudi/build.$PLATFORM
make Gaudi
make Gaudi/configure  # test a reconfigure
bash utils/ci-utils/test-cmake.sh Gaudi/build.$PLATFORM
make Detector/configure
bash utils/ci-utils/test-cmake.sh Detector/build.$PLATFORM
make LHCb/configure
bash utils/ci-utils/test-cmake.sh LHCb/build.$PLATFORM
bash utils/ci-utils/test-misc.sh

utils/stats
