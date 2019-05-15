#!/bin/bash

bash $(dirname $0)/install-cmake.sh
bash $(dirname $0)/install-ninja.sh
bash $(dirname $0)/install-ccache.sh
bash $(dirname $0)/install-distcc.sh
bash $(dirname $0)/install-tools.sh