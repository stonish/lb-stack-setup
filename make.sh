#!/bin/bash
set -eo pipefail

# exec 3>&2 2> >(tee /tmp/sample-time.$$.log |
#                  sed -u 's/^.*$/now/' |
#                  date -f - +%s.%N >/tmp/sample-time.$$.tim)
# set -x  # trace the script for debugging

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/helpers.sh"
logname="make.sh"
printenv | sort > "$OUTPUT/make.sh.env"

PROJECT="$1"
TARGET="$2"
if [ "$#" -ne 2 ]; then
    echo "usage: $(basename $0) project target" >&2
    exit 2
fi

# steering options
CONTRIB="$(config contribPath)"
OUTPUT="$(config outputPath)"
USE_CCACHE=$(config useCcache)
USE_DISTCC=$(config useDistcc)
USE_DISTCC_PUMP=true
# DEBUG_DISTCC=true; USE_CCACHE=false
# DEBUG_CCACHE=true

# explicitly define a fast TMPDIR
# FIXME this may result in /tmp/<username>/<id> which is a bit redundant
export TMPDIR="${XDG_RUNTIME_DIR:-$(dirname $(mktemp -u))/$(id -u)}"
mkdir -p $TMPDIR
# use our CMake and set the toolchain
export PATH=$CONTRIB/bin:$PATH
export CMAKEFLAGS="$CMAKEFLAGS '-DCMAKE_TOOLCHAIN_FILE=$DIR/toolchain.cmake'"
# more informative build progress [notstarted>running>finished/total]
export NINJA_STATUS="[%u>%r>%f/%t] "


setup_ccache() {
  export CCACHE_DIR="$(config ccachePath)"

  # Setup ccache limits only if not setup
  [ ! -d "$CCACHE_DIR" ] && ccache -F 20000 -M 0

  # Use a fast directory for temporaries
  export CCACHE_TEMPDIR="$TMPDIR/ccache"
  # Use some sane sloppines (see ccache docs)
  # - set locale to C to get consistent compiler messages
  # - only include system headers in the hash but not add the system header files to the list of include files
  #   This allows ccache to only check non-system headers, but will also cause
  #   it to return stale cache hits if such system headers have been changed.
  export LANG=C LC_ALL=C LC_CTYPE=C LC_MESSAGES=C
  export CCACHE_SLOPPINESS="locale,system_headers"

  # Increase hit rate by
  # - rewriting absolute paths into relative paths using a base directory
  export CCACHE_BASEDIR="$PWD/$PROJECT"
  # - not including CWD in hash (debug info might be incorrect)
  export CCACHE_NOHASHDIR=1
  # see https://ccache.dev/manual/latest.html#_compiling_in_different_directories
  # TODO use the -fdebug-prefix-map=old=new

  # Use generated depenencies instead of the preprocessor, much faster!
  export CCACHE_DEPEND=1
  # Use a log (tiny overhead) to display stats later (hits and misses),
  # see https://github.com/ccache/ccache/issues/262
  export CCACHE_LOGFILE="$OUTPUT/ccache.log"

  mkdir -p "$CCACHE_TEMPDIR" "$OUTPUT"
  rm -f "$CCACHE_LOGFILE"  # clear logfile

  if [ "$DEBUG_CCACHE" = true ]; then
    CCACHE_DEBUG=1
    CCACHE_READONLY=1
  fi
}


pump_startup() {
  # start the include server manually (instead of pump --startup) for more control
  # TODO hardcoded python3
  local PYTHON=/cvmfs/sft.cern.ch/lcg/releases/LCG_96bpython3/Python/3.6.5/x86_64-centos7-gcc9-opt/bin/python
  local include_server_install="$CONTRIB/lib/python3.6/site-packages/include_server"
  local pid_file="$OUTPUT/distcc-pump.pid"

  # kill stray include servers (as pump relies on no changes during build)
  pkill -f "$include_server_install/include_server.py --port" || true

  if [ "$DEBUG_DISTCC" = true ]; then
    # --time = Print elapsed, user, and system time to stderr.
    # --statistics = Print information to stdout about include analysis.
    # --debug_pattern : 19 = 1 (warning) + 2 (trace 0) + 16 (data); 31 = everything
    local debug_args="--time --statistics --debug_pattern=19 --path_observation_re cvmfs"
  else
    local debug_args="--debug_pattern=1"  # only warnings
  fi

  # Variable used by "pump --shutdown" (see pump_shutdown)
  export INCLUDE_SERVER_DIR=$(mktemp -d -t distcc-pump-socket-XXXXXX)
  # Variable used by the distcc client
  export INCLUDE_SERVER_PORT="$INCLUDE_SERVER_DIR/socket"

  mkdir -p "$OUTPUT"

  # TODO add a separator line to the stdout/stderr or rotate logs
  # Start the include server directly, avoiding the `pump` wrapper.
  # This allows more control, e.g. to chose the version of python
  PYTHONPATH="$PYTHONPATH:$include_server_install" \
    $PYTHON $include_server_install/include_server.py \
      --port $INCLUDE_SERVER_PORT --pid_file "$pid_file" \
      $debug_args \
      >"$OUTPUT/distcc-pump.stdout" \
      2>"$OUTPUT/distcc-pump.stderr"

  # Variable used by "pump --shutdown" (see pump_shutdown)
  export INCLUDE_SERVER_PID=$(cat "$pid_file")
}


pump_shutdown() {
  # TODO add a separator line to the stdout/stderr or rotate logs
  pump --shutdown | grep -v '___Shutting down' || true
  # $INCLUDE_SERVER_PORT and $INCLUDE_SERVER_DIR are removed by pump
}


setup_distcc_hosts() {
  # TODO setup_distcc_hosts is slow when outside CERN.
  # Consider doing port forwarding it a distcc wrapper.

  local distcc_env
  if ! distcc_env=$(python "$DIR/setup-distcc.py"); then
    return 1
  fi
  eval $distcc_env
  local ndistcc=$(echo "$("$CONTRIB/bin/distcc" -j) * 5/4" | bc)
  export NINJAFLAGS="$NINJAFLAGS -j$ndistcc"
}


setup_distcc() {
  if setup_distcc_hosts ; then
    if [ "$USE_DISTCC_PUMP" = true ]; then
      pump_startup
    else
      # give distcc the preprocessed source to skip the double preprocessing
      # on cache miss
      # TODO this disables ccache depend mode, check performance
      export CCACHE_NOCPP2=1
      # limit local preprocessing by ccache as doing 100s at a time is bad
      export CCACHE_PREFIX_CPP="$DIR/cpp_prefix.sh"
    fi

    # DEBUGGING
    if [ "$DEBUG_DISTCC" = true ]; then
      export DISTCC_VERBOSE=1
      # export DISTCC_LOG=$OUTPUT/distcc.log
      # rm -f ${DISTCC_LOG}

      export DISTCC_SAVE_TEMPS=1
      # distcc uses TMPDIR for temporary files, so set that
      export COMPILER_PREFIX="TMPDIR='$OUTPUT/distcc-tmp' $COMPILER_PREFIX"
      mkdir -p "$OUTPUT/distcc-tmp"

      export DISTCC_FALLBACK=0  # disable fallbacks and fail
      export DISTCC_BACKOFF_PERIOD=0  # disable backoff
      export NINJAFLAGS="$NINJAFLAGS -j1"  # one job at a time
    fi
  else
    log ERROR "Failed to set up hosts for distcc"
    exit 1
  fi
}


# TODO remove this in a couple of months (September)
if [ "$USE_DISTCC" = true ]; then
  if ! gitc "$PROJECT/../Gaudi" grep -q GENREFLEX_JOB_POOL -- \
      cmake/modules/EnableROOT6.cmake; then
    log ERROR "GENREFLEX_JOB_POOL not supported by Gaudi cmake!"
    log ERROR "Please update to latest master or cherry pick 5dd5dceb26"
    exit 1
  fi
fi

if [ -f Makefile ]; then
  # FIXME check wont't work when PROJECT is a multi-dir path
  if [ "$PROJECT" = Gaudi ] && [ -f "$PROJECT/Makefile" ]; then
    # FIXME remove the following once Makefile is removed from Gaudi
    # update-index is needed as older git diff-index only does a "quick look"
    # see https://stackoverflow.com/a/34808299
    gitc "$PROJECT" update-index --refresh &>/dev/null || true
    if gitc "$PROJECT" diff-index --quiet HEAD -- Makefile; then
      rm -f "$PROJECT/Makefile"
      # hide the removed file from status and diffs
      gitc "$PROJECT" update-index --assume-unchanged Makefile
    else
      log ERROR "Could not remove Gaudi/Makefile safely!"
      log ERROR "Please commit or undo any local modifications"
      exit 1
    fi
  else
    # FIXME tremove the following in two months (September)
    # ruthlessly delete any untracked Makefile or toolchain
    gitc "$PROJECT" clean -xf -- Makefile toolchain.cmake
  fi
fi

# Disable distcc for targets that do not cause compilation
if [ "$USE_DISTCC" = true ]; then
  if [[ "purge clean configure test" =~ (^|[[:space:]])"$TARGET"($|[[:space:]]) ]]; then
    USE_DISTCC=false
  fi
fi

# Disable distcc when there are few cxx to build.
# This saves the overheads when iterating on some file.
if [ "$USE_DISTCC" = true -a "$DEBUG_DISTCC" != true ]; then
  if [ -f "$PROJECT/build.$BINARY_TAG/build.ninja" ]; then
    ninja_todo=$("$CONTRIB/bin/ninja" -C "$PROJECT/build.$BINARY_TAG" -n | \
      grep 'Building CXX object\|Re-running CMake' | head -2 || true)
    # do not disable distcc when rerunning CMake
    if [[ $ninja_todo != *'CMake'* ]]; then
      n_cxx_to_build=$(printf '%s' "$ninja_todo" | wc -l)
      if [[ $n_cxx_to_build -le 1 ]]; then
        USE_DISTCC=false
      fi
    fi
  fi
fi

[ "$USE_CCACHE" = true ] && setup_ccache
[ "$USE_DISTCC" = true ] && setup_distcc

# Define compiler prefix used in compile.sh
if [ "$USE_CCACHE" = true ]; then
  export COMPILER_PREFIX="$DIR/../contrib/bin/ccache"
  if [ "$USE_DISTCC" = true ]; then
    export CCACHE_PREFIX="$DIR/../contrib/bin/distcc"
  fi
elif [ "$USE_DISTCC" = true ]; then
  export COMPILER_PREFIX="$DIR/../contrib/bin/distcc"
fi

make -f "$DIR/project.mk" -C "$PROJECT" "$TARGET"
# TODO catch CTRL-C during make here and do the clean up, see
#      https://unix.stackexchange.com/questions/163561/control-which-process-gets-cancelled-by-ctrlc
run_cmd="$PROJECT/build.$BINARY_TAG/run"
if [ -f $run_cmd ]; then
  $run_cmd >"$PROJECT/build.$BINARY_TAG/python.env" &2>/dev/null || true
fi

###########################################################
# clean up
###########################################################
if [ "$USE_DISTCC" = true ]; then
  if [ "$USE_DISTCC_PUMP" = true ]; then
    pump_shutdown
  fi
fi
if [ "$USE_CCACHE" = true ]; then
  # print ccache stats
  (grep -E -o "Result: .*" "$CCACHE_LOGFILE" 2> /dev/null | sort | uniq -c) || true
fi
