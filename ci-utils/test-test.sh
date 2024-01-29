DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/framework.sh"

PROJECT="${1:-LHCb}"

if [ $(make Gaudi/test ARGS="-N -R GaudiExamples.templatedalg" | grep 'Test #' | wc -l) -le 1 ]
then
    error 'Did GaudiExamples.templatedalg* tests get removed?'
fi

if [ $(make Gaudi/test ARGS="-N -R GaudiExamples.templatedalg$" | grep 'Test #' | wc -l) != 1 ]
then
    error 'Using $ inside ARGS= is not working'
fi
