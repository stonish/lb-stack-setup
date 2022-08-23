DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/framework.sh"


if ! ls /cvmfs/{lhcb,lhcb-condb,lhcbdev,sft}.cern.ch/
then
    error 'Cannot access cvmfs repositories'
fi

# if ! klist
# then
#     error 'klist failed'
# fi

# Check forwarding of environment variables
# - not propagated when not defined
unset DISPLAY
if utils/build-env env | grep '^DISPLAY='
then
    error 'Undefined variable should not be propagated'
fi
# - propagated when defined (empty or not)
if ! DISPLAY= utils/build-env env | grep '^DISPLAY=$'
then
    error 'Defined empty variable should be propagated'
fi
if ! DISPLAY=abc utils/build-env env | grep '^DISPLAY=abc$'
then
    error 'Defined non-empty variable should be propagated'
fi

# Check that other variables are not propagated
if BLAH=blah utils/build-env env | grep '^BLAH=blah$'
then
    error 'Variable not listed in forwardEnv should not be propagated'
fi
