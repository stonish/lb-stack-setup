#!/bin/bash
set -e
#set -x  # trace the script for debugging

USE_DISTCC="${USE_DISTCC:-true}"
USE_DISTCC_PUMP="${USE_DISTCC_PUMP:-true}"
USE_CCACHE="${USE_CCACHE:-true}"

DEBUG_DISTCC=false
TMPDIR_DISTCC=`pwd`/.distcc
LOCAL_TOOLS=`pwd`/contrib

# take localslots{_cpp} from the number of logical cores
nproc=$(nproc)
nproc2x=$(expr $nproc \* 2)

export PATH=$LOCAL_TOOLS/bin:$PATH
#export PATH=/cvmfs/lhcb.cern.ch/lib/contrib/CMake/3.14.3/Linux-x86_64/bin:$PATH
# Make absolutely sure cmake will use the local install of ninja, ccache and distcc
export CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_MAKE_PROGRAM:FILEPATH=$LOCAL_TOOLS/bin/ninja"
export CMAKEFLAGS="$CMAKEFLAGS -Dccache_cmd:FILEPATH=$LOCAL_TOOLS/bin/ccache"
export CMAKEFLAGS="$CMAKEFLAGS -Ddistcc_cmd:FILEPATH=$LOCAL_TOOLS/bin/distcc"

export NINJA_STATUS="[%u>%r>%f/%t] "


setup_distcc_hosts() {
  export DISTCC_HOSTS="--localslots=$nproc --localslots_cpp=$nproc2x --randomize"
  export DISTCC_HOSTS="$DISTCC_HOSTS lbquantaperf01.cern.ch/40,cpp,lzo,auth"
  export DISTCC_HOSTS="$DISTCC_HOSTS lbquantaperf02.cern.ch/40,cpp,lzo,auth"
  # export DISTCC_HOSTS="$DISTCC_HOSTS 127.0.0.1:36321/40,cpp,lzo,auth=lbquantaperf01.cern.ch"
  export DISTCC_PRINCIPAL=distccd
  export NINJAFLAGS=${NINJAFLAGS:-"-j100"}
  return 0
  set +e
  nc -w 2 localhost 11111 </dev/null 2> /dev/null || \
    ssh -f -N -o ExitOnForwardFailure=yes -L 11111:hltperf-quanta01-e52630v4:12345 -L 11112:hltperf-quanta02-e52630v4:12345 lbgw.cern.ch
  ok=$?
  set -e
  if [ $ok -eq 0 ]; then
    # "localhost" has a special meaning for distcc -> use "127.0.0.1"
    # TODO add cpp conditionally on USE_DISTCC_PUMP
    export DISTCC_HOSTS="$DISTCC_HOSTS 127.0.0.1:11111/40,lzo,cpp 127.0.0.1:11112/40,lzo,cpp"
    export NINJAFLAGS=${NINJAFLAGS:-"-j100"}
    echo $NINJAFLAGS
    # TODO The number of jobs needs automation
  fi
  return $ok
}

pump_startup() {
  pkill -f 'include_server.py --port' || true  # kill stray include servers TODO do we really need to?
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
  PYTHON=/cvmfs/sft.cern.ch/lcg/releases/LCG_95apython3/Python/3.6.5/x86_64-centos7-gcc8-opt/bin/python
  include_server_install="$LOCAL_TOOLS/lib/python3.6/site-packages/include_server"
  # TODO add a separator line to the stdout/stderr or rotate logs
  # Start the include server directly, avoiding the `pump` wrapper.
  # This allows more control, e.g. to chose the version of python
  PYTHONPATH="$PYTHONPATH:$include_server_install" \
    $PYTHON $include_server_install/include_server.py \
      --port $INCLUDE_SERVER_PORT --pid_file $TMPDIR_DISTCC/pump.pid \
      -t -s \
      > $TMPDIR_DISTCC/pump-startup.stdout 2> $TMPDIR_DISTCC/pump-startup.stderr
  # debugging flags can be added above, e.g. "-d19 (-d1) --path_observation_re cvmfs"
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
  # Use some sane sloppines (see ccache docs)
  # - set locale to C to get consistent compiler messages
  # - only include system headers in the hash but not add the system header files to the list of include files
  #   This allows ccache to only check non-system headers, but will also cause
  #   it to return stale cache hits if such system headers have been changed.
  export LANG=C LC_ALL=C LC_CTYPE=C LC_MESSAGES=C
  export CCACHE_SLOPPINESS="locale,system_headers"
  export CCACHE_NOHASHDIR=1  # debug info might be incorrect

  export CCACHE_DEPEND=1  # use generated depenencies instead of the preprocessor
  
  export CCACHE_DIR=${PWD}/.ccache
  export CCACHE_TEMPDIR=${XDG_RUNTIME_DIR:-$(dirname $(mktemp -u))/$(id -u)}/ccache-tmp  # use a faster TMPDIR
  export CCACHE_DEBUG=1
  export CCACHE_LOGFILE=${PWD}/.ccache.log
  mkdir -p ${CCACHE_TEMPDIR}
fi

if [ "$MAKE" = true ]; then
  if [ "$USE_CCACHE" = true ]; then
    export CMAKEFLAGS="$CMAKEFLAGS -DCMAKE_USE_CCACHE=ON"  # use ccache
    export CCACHE_BASEDIR="${PWD}/${PROJECT}"
    rm -f $CCACHE_LOGFILE  # clear logfile
  fi
  export CMAKEFLAGS="$CMAKEFLAGS -DGAUDI_DIAGNOSTICS_COLOR=ON"
  export CMAKE_PREFIX_PATH=${PWD}:${CMAKE_PREFIX_PATH}
  # TODO what if we don't build Gaudi???
  export CMAKEFLAGS="$CMAKEFLAGS -Ddefault_toolchain:FILEPATH=${PWD}/Gaudi/cmake/GaudiDefaultToolchain.cmake"
  # Use toolchain from local Gaudi
  unset VERBOSE  # Reduce verbosity
  # Disable functor cache
  if [[ " Brunel Moore DaVinci " =~ " $PROJECT " ]]; then
    export CMAKEFLAGS="$CMAKEFLAGS -DLOKI_BUILD_FUNCTOR_CACHE=OFF"
  fi

  if [ "$USE_DISTCC" != true ]; then
    export NINJAFLAGS="-j ${nproc2x}"  # TODO
  fi

  ###########################################################
  # distcc setup
  ###########################################################
  if [ "$USE_DISTCC" = true ]; then
    export CCACHE_NOCPP2=1  # give distcc the preprocessed source and skip the double preprocessing on cache miss
    export CMAKEFLAGS="${CMAKEFLAGS} -DCMAKE_USE_DISTCC=ON"
    export CMAKEFLAGS="${CMAKEFLAGS} -DCMAKE_JOB_POOLS='local=$nproc2x' -DCMAKE_JOB_POOL_LINK=local -DCMAKE_JOB_POOL_GENREFLEX=local"
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
  if [ "$USE_CCACHE" = true ]; then
    grep -E -o "Result: .*" "$CCACHE_LOGFILE" 2> /dev/null | sort | uniq -c  # ccache stats
  fi
fi
