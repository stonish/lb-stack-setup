# mimic docker entry point
for i in /cvmfs/lhcb.cern.ch/lib/etc/cern_profile.d/*.sh ; do
    if  [ -r "$i" ] ; then
        . "$i"
    fi
done

# Workaround for https://gitlab.cern.ch/lhcb-core/LbEnv/issues/20
# (MAKEFLAGS can contain dollar signs)
_makeflags="$MAKEFLAGS"

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
test -d "$DIR/LbEnv" && export OVERRIDE_LBENVROOT="$DIR/LbEnv"

. /cvmfs/lhcb.cern.ch/lib/LbEnv.sh --quiet --sh --platform ${BINARY_TAG}
test -z "$LBENV_SOURCED" && exit 1

# Use lcg compiler wrappers for centos7.
# TODO remove once centos8 is supported in LHCb
export PATH=/cvmfs/lhcb.cern.ch/lib/bin/x86_64-centos7:$PATH

export MAKEFLAGS="$_makeflags"

"$@"
