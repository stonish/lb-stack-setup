DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/framework.sh"

PROJECT="${1:-LHCb}"

if [ ! "$($PROJECT/run pwd)" = "$(pwd)" ]
then
    error '<project>/run does not work'
fi

if [ ! "$(cd $PROJECT && ./run pwd)" = "$(pwd)/$PROJECT" ]
then
    error '`cd <project>; ./run` does not work'
fi

if [ "$LEGACY" != "1" ]
then
    if ! $PROJECT/gdb --version | grep "GNU gdb"
    then
        error '<project>/gdb does not work'
    fi

    if ! ( cd $PROJECT && ./gdb --version | grep "GNU gdb" )
    then
        error '`cd <project>; ./gdb` does not work'
    fi
fi

if ! $PROJECT/run python -c 'import PRConfig; assert "v999r999" in PRConfig.__file__'
then
    error 'PRConfig is not picked up from the local clone'
fi
