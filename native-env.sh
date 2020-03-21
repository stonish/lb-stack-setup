set -eo pipefail

# mimic docker entry point
for i in /cvmfs/lhcb.cern.ch/lib/etc/cern_profile.d/*.sh ; do
    if  [ -r "$i" ] ; then
        . "$i"
    fi
done

. "$1" --quiet --platform $2
env -0 | sort -z | xargs -0 bash -c 'printf "export %q\n" "$@"'
# FIXME workaround for LbEnv.sh --sh
