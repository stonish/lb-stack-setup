#!/bin/bash
self=$(target=$0 perl -le 'print readlink $ENV{target}')
$(dirname $self)/run-env $(dirname $0) "$@"