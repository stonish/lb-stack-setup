DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/framework.sh"

LHCb_or_mono=LHCb
if [ -x mono/run ]
then
    LHCb_or_mono=mono
fi

if [ ! "$($LHCb_or_mono/run pwd)" = "$(pwd)" ]
then
    error '<project>/run does not work'
fi

if [ ! "$(cd $LHCb_or_mono && ./run pwd)" = "$(pwd)/$LHCb_or_mono" ]
then
    error '`cd <project>; ./run` does not work'
fi

if [ "$LEGACY" != "1" ]
then
    if ! $LHCb_or_mono/gdb --version | grep "GNU gdb"
    then
        error '<project>/gdb does not work'
    fi

    if ! ( cd $LHCb_or_mono && ./gdb --version | grep "GNU gdb" )
    then
        error '`cd <project>; ./gdb` does not work'
    fi
fi

if [ $(make Gaudi/test ARGS="-N -R GaudiExamples.templatedalg" | grep 'Test #' | wc -l) -le 1 ]
then
    error 'Did GaudiExamples.templatedalg* tests get removed?'
fi

if [ $(make Gaudi/test ARGS="-N -R GaudiExamples.templatedalg$" | grep 'Test #' | wc -l) != 1 ]
then
    error 'Using $ inside ARGS= is not working'
fi

if ! $LHCb_or_mono/run python -c 'import PRConfig; assert "v999r999" in PRConfig.__file__'
then
    error 'PRConfig is not picked up from the local clone'
fi

