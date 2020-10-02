set -eo pipefail

# mimic docker entry point
for i in /cvmfs/lhcb.cern.ch/lib/etc/cern_profile.d/*.sh ; do
    if  [ -r "$i" ] ; then
        . "$i"
    fi
done

lbenvPath=$1
. "$lbenvPath"/bin/LbEnv.sh --quiet --siteroot /cvmfs/lhcb.cern.ch/lib

# Use lcg compiler wrappers for centos7.
# TODO remove once centos8 is supported in LHCb
export PATH=/cvmfs/lhcb.cern.ch/lib/bin/x86_64-centos7:$PATH

# print the entire environment
env -0 | sort -z | xargs -0 bash -c 'printf "export %q\n" "$@"' _arg0
