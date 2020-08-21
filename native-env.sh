set -eo pipefail

# mimic docker entry point
for i in /cvmfs/lhcb.cern.ch/lib/etc/cern_profile.d/*.sh ; do
    if  [ -r "$i" ] ; then
        . "$i"
    fi
done
. "$1" --quiet
env -0 | sort -z | xargs -0 bash -c 'printf "export %q\n" "$@"' _arg0
# FIXME workaround for LbEnv.sh --sh
