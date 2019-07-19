# mimic docker entry point
for i in /cvmfs/lhcb.cern.ch/lib/etc/cern_profile.d/*.sh ; do
    if  [ -r "$i" ] ; then
        . "$i"
    fi
done

. /cvmfs/lhcb.cern.ch/lib/LbEnv.sh --quiet --sh --platform ${BINARY_TAG}

"$@"
