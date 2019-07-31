# mimic docker entry point
for i in /cvmfs/lhcb.cern.ch/lib/etc/cern_profile.d/*.sh ; do
    if  [ -r "$i" ] ; then
        . "$i"
    fi
done

# Workaround for https://gitlab.cern.ch/lhcb-core/LbEnv/issues/20
# (MAKEFLAGS can contain dollar signs)
_makeflags="$MAKEFLAGS"

. /cvmfs/lhcb.cern.ch/lib/LbEnv.sh --quiet --sh --platform ${BINARY_TAG}

export MAKEFLAGS="$_makeflags"

"$@"
