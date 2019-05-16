#!/bin/bash

DIR=$(dirname $0)

utils/build-env bash -c "
bash "$DIR/install-cmake.sh"
bash "$DIR/install-ninja.sh"
bash "$DIR/install-ccache.sh"
bash "$DIR/install-distcc.sh"
"

bash $DIR/install-tools.sh