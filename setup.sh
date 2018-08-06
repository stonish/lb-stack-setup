#!/bin/bash
set -e
#set -x  # trace the script for debugging

USE_DISTCC=true
USE_DISTCC_PUMP=true
USE_CCACHE=true

DEBUG_DISTCC=false
TMPDIR_DISTCC=`pwd`/.distcc
LOCAL_TOOLS=`pwd`/tools

# take localslots{_cpp} from the number of logical cores
nproc=$(nproc)
nproc2x=$(expr $nproc \* 2)

setup_distcc_hosts() {
  set +e
  nc -w 2 localhost 11111 </dev/null 2> /dev/null || \
    ssh -f -N -o ExitOnForwardFailure=yes -L 11111:hltperf-quanta01-e52630v4:12345 -L 11112:hltperf-quanta02-e52630v4:12345 lbgw.cern.ch
  ok=$?
  set -e
  if [ $ok -eq 0 ]; then
    # "localhost" has a special meaning for distcc -> use "127.0.0.1"
    # TODO add cpp conditionally on USE_DISTCC_PUMP
    export DISTCC_HOSTS="--localslots=$nproc --localslots_cpp=$nproc2x 127.0.0.1:11111/40,lzo,cpp 127.0.0.1:11112/40,lzo,cpp --randomize"
    #export DISTCC_HOSTS="--localslots=2 --localslots_cpp=2 rmatev04.cern.ch/4,lzo,cpp,auth --randomize"
    export NINJAFLAGS=${NINJAFLAGS:-"-j100"}
    # TODO The number of jobs needs automation
  fi
  return $ok
}

pump_startup() {
  pkill -f include_server || true  # kill stray include servers TODO do we really need to?
  # start the include server manually (instead of pump --startup) for more control
  INCLUDE_SERVER_DIR=$TMPDIR_DISTCC/socket
  mkdir -p $INCLUDE_SERVER_DIR
  export INCLUDE_SERVER_PORT=$INCLUDE_SERVER_DIR/socket  # used by the distcc client
  # if [ -f "$TMPDIR_DISTCC/pump.pid" ]; then
  #   if ps -p `cat $TMPDIR_DISTCC/pump.pid` > /dev/null; then
  #     echo "Reusing existing include_server"
  #     return 0
  #   fi
  # fi

  # TODO find a better way to start the include_server
  python_version=`python3 --version | grep -o '3\.[0-9]*'`
  include_server_install="$LOCAL_TOOLS/lib64/python$python_version/site-packages/include_server"
  # TODO add a separator line to the stdout/stderr or rotate logs
  PYTHONPATH="$PYTHONPATH:$include_server_install" \
    python3 $include_server_install/include_server.py \
      --port $INCLUDE_SERVER_PORT --pid_file $TMPDIR_DISTCC/pump.pid \
      -t -s \
      > $TMPDIR_DISTCC/pump-startup.stdout 2> $TMPDIR_DISTCC/pump-startup.stderr
  # debugging flags -d19 (-d1) --path_observation_re cvmfs
}

pump_shutdown() {
  if [ -f "$TMPDIR_DISTCC/pump.pid" ]; then
    # TODO add a separator line to the stdout/stderr or rotate logs
    PATH="$LOCAL_TOOLS/bin:$PATH"
    INCLUDE_SERVER_DIR=$TMPDIR_DISTCC/socket \
    INCLUDE_SERVER_PID=`cat $TMPDIR_DISTCC/pump.pid` \
      pump --shutdown > $TMPDIR_DISTCC/pump-shutdown.stdout 2> $TMPDIR_DISTCC/pump-shutdown.stderr
    rm -f $TMPDIR_DISTCC/pump.pid  # TODO test if process exists?
  fi
  true
}

###########################################################
# Option parsing
###########################################################
OPTS=`getopt -o m:s --long make:,stop -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then echo "Failed parsing options." >&2 ; exit 1 ; fi
eval set -- "$OPTS"

MAKE=false
STOP=false
while true; do
  case "$1" in
    -s | --stop ) STOP=true; shift ;;
    -m | --make ) MAKE=true; PROJECT="$2"; shift; shift ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done
# TODO enforce exclusivity of BUILD and STOP

###########################################################
# Setup unconditional on invocation
###########################################################
if [ "$USE_CCACHE" = true ]; then
  export CCACHE_DIR=${PWD}/.ccache
  export CCACHE_TEMPDIR=${XDG_RUNTIME_DIR:-$(dirname $(mktemp -u))/$(id -u)}/ccache-tmp  # use a faster TMPDIR
  mkdir -p ${CCACHE_TEMPDIR}
  #export CCACHE_LOGFILE=$(dirname $(mktemp -u))/ccache.debug
fi

if [ "$MAKE" = true ]; then
  [ "$USE_CCACHE" = true ] && export CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_USE_CCACHE=ON"  # use ccache
  export CMAKEFLAGS="$CMAKEFLAGS -DGAUDI_DIAGNOSTICS_COLOR=ON"
  export CMAKE_PREFIX_PATH=${PWD}:${CMAKE_PREFIX_PATH}
  export CMAKE_PREFIX_PATH=${PWD}/Gaudi/cmake:${CMAKE_PREFIX_PATH}  # Use toolchain from local Gaudi
  unset VERBOSE  # Reduce verbosity
  # Disable functor cache
  if [[ " Brunel Moore DaVinci " =~ " $PROJECT " ]]; then
    export CMAKEFLAGS="$CMAKEFLAGS -DLOKI_BUILD_FUNCTOR_CACHE=OFF"
  fi

  ###########################################################
  # distcc setup
  ###########################################################
  if [ "$USE_DISTCC" = true ]; then
    export PATH=`pwd`:${PATH}  # override distcc with the local wrapper
    export CCACHE_NOCPP2=1  # give distcc the preprocessed source and skip the double preprocessing on cache miss
    export CMAKEFLAGS="${CMAKEFLAGS} -DCMAKE_USE_DISTCC=ON"
    export CMAKEFLAGS="${CMAKEFLAGS} -DCMAKE_JOB_POOLS='link_pool=$nproc2x' -DCMAKE_JOB_POOL_LINK=link_pool"
    export DISTCC_HOSTS="localhost"
    setup_distcc_hosts
    if [ $? -eq 0 ]; then
      # limit local preprocessing by ccache as doing 100s at a time is bad
      export CCACHE_PREFIX_CPP="`pwd`/cpp_prefix.sh"

      if [ "$USE_DISTCC_PUMP" = true ]; then
        unset CCACHE_NOCPP2  # pump mode does not work with preprocessed files
        pump_startup
      fi

      # DEBUGGING
      if [ "$DEBUG_DISTCC" = true ]; then
        distcc --show-hosts
        mkdir -p $TMPDIR_DISTCC
        export DISTCC_FALLBACK=0
        export DISTCC_LOG=$TMPDIR_DISTCC/distcc.log
        export DISTCC_VERBOSE=1
        export DISTCC_SAVE_TEMPS=1
        export NINJAFLAGS=-j1
        rm -f $HOME/.distcc/lock/backoff*
        # rm -f ${DISTCC_LOG}  # TODO rotate the log instead
      fi
    else
      echo "Could not setup hosts for distcc"
      exit 1
    fi
  fi

  # Tweaks for LXPLUS
  if [[ $(hostname) == lxplus* ]]; then
    # don't be too aggressive or else g++ gets killed
    export NINJAFLAGS=-j6
  fi
fi  # BUILD


if [ "$STOP" = true ]; then
  if [ "$USE_DISTCC_PUMP" = true ]; then
    pump_shutdown
  fi
fi
