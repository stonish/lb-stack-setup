#!/bin/bash
set -eo pipefail

# exec 3>&2 2> >(tee /tmp/sample-time.$$.log |
#                  sed -u 's/^.*$/now/' |
#                  date -f - +%s.%N >/tmp/sample-time.$$.tim)
# set -x  # trace the script for debugging

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$DIR/helpers.sh"
logname="make.sh"

if [ "$#" -lt 2 ]; then
    echo "usage: $(basename $0) project targets" >&2
    exit 2
fi
PROJECT="$1"
shift

# steering options
source_config outputPath contribPath buildPath targetBuildPath ccachePath useCcache useDistcc cmakePrefixPath \
                   'ccacheHosts=ccacheHosts or ccacheHostsPresets.get(ccacheHostsKey, "")'
OUTPUT=$outputPath
CONTRIB=$contribPath
BUILD_PATH=$buildPath
USE_CCACHE=$useCcache
USE_DISTCC=$useDistcc
USE_DISTCC_PUMP=true
# DEBUG_DISTCC=true; USE_CCACHE=false
# DEBUG_CCACHE=true
setup_output
printenv | sort > "$OUTPUT/make.sh.env"

# explicitly define a fast TMPDIR, unless debugging
if [ "$DEBUG_CCACHE" = true -o "$DEBUG_DISTCC" = true ]; then
  export TMPDIR="$OUTPUT/tmp"
else
  # FIXME this may result in /tmp/<username>/<id> which is a bit redundant
  export TMPDIR="${XDG_RUNTIME_DIR:-$(dirname $(mktemp -u))/$(id -u)}"
fi
mkdir -p $TMPDIR
# use our CMake
export PATH=$CONTRIB/bin:$PATH
# force a particular ninja executable since for some reason CMake does not
# look into PATH and picks up /usr/bin/ninja-build when present.
export CMAKE_MAKE_PROGRAM=$CONTRIB/bin/ninja
# more informative build progress [notstarted>running>finished/total]
export NINJA_STATUS="[%u>%r>%f/%t] "


setup_ccache() {
  export CCACHE_DIR="$ccachePath"

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
  # export CCACHE_SLOPPINESS="locale,system_headers"
  export CCACHE_SLOPPINESS="locale"
  # FIXME: system headers are cannot be ignored at present because upstream
  #        projects are included as -isystem .
  #        See https://gitlab.cern.ch/lhcb/LHCb/-/issues/191
  export CCACHE_COMPILERCHECK="none"
  # Do not check the compiler as its name is always in the cache key
  # and it is already unique (e.g. "g++-11.1.0-e80bf-2.36.1-a9696"), see toolchain.cmake
  # FIXME: We can remove this once the lcg-toolchains wrapper is fixed
  #        to not depend on PATH and have the wrapper content stable.

  # Increase hit rate by
  # - rewriting absolute paths that start with $PWD into relative ones
  #   So a compilation unit in LHCb which for example includes -I /full_path_to_lb_stack_folder/Gaudi/InstallArea/...
  #   willl have it's path rewritten to one that is relative to the current working directory, before ccache hashes
  #   This means that I can share a cache between different lb-stack setups :)
  export CCACHE_BASEDIR="$PWD"
  # - rewrite absolute paths in stderr to not get wrong paths in e.g. warning messages
  export CCACHE_ABSSTDERR=1
  # - using -ffile-prefix-map (see toolchain.cmake). CCACHE_NOHASHDIR=1 is not needed.
  #   See https://ccache.dev/manual/latest.html#_compiling_in_different_directories
  #   Needs recent distcc server, see https://github.com/distcc/distcc/pull/459

  # Secondary cache
  export CCACHE_SECONDARY_STORAGE="$ccacheHosts"

  # Use generated depenencies instead of the preprocessor, much faster!
  export CCACHE_DEPEND=1
  # Keep track of stats for this build.
  export CCACHE_STATSLOG="$OUTPUT/stats/$BINARY_TAG/$PROJECT.ccache-statslog"
  rm -f "$CCACHE_STATSLOG"  # clear stats

  mkdir -p "$CCACHE_TEMPDIR" $(dirname $CCACHE_STATSLOG)

  if [ "$DEBUG_CCACHE" = true ]; then
    export CCACHE_DEBUG=1
    export CCACHE_READONLY=1
    export CCACHE_DEBUGDIR="$CCACHE_TEMPDIR/debug/$PROJECT/"
    export CCACHE_LOGFILE="$OUTPUT/ccache.log"
    rm -f "$CCACHE_LOGFILE"  # clear logfile
  fi
}


pump_startup() {
  # start the include server manually (instead of pump --startup) for more control
  local include_server_install=$(python -c "
import sysconfig
print(sysconfig.get_path('purelib', vars={'base': '$CONTRIB'}))
  ")/include_server
  local pid_file="$OUTPUT/distcc-pump.pid"

  # kill stray include servers (as pump relies on no changes during build)
  pkill -f "$include_server_install/include_server.py --port" || true

  if [ "$DEBUG_DISTCC" = true ]; then
    # --time = Print elapsed, user, and system time to stderr.
    # --statistics = Print information to stdout about include analysis.
    # --debug_pattern : 19 = 1 (warning) + 2 (trace 0) + 16 (data); 31 = everything
    local debug_args="--time --statistics --debug_pattern=19"
    # debug_args="$debug_args --path_observation_re=/cvmfs"
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
  # (not necessarily the one used to build )
  local cmd="PYTHONPATH='$PYTHONPATH:$include_server_install' \
    python '$include_server_install/include_server.py' \
      --port '$INCLUDE_SERVER_PORT' --pid_file '$pid_file' \
      $debug_args"
  if [ "$DEBUG_DISTCC" != true ]; then
    cmd="$cmd >'$OUTPUT/distcc-pump.stdout' 2>'$OUTPUT/distcc-pump.stderr'"
  fi
  eval $cmd

  # Variable used by "pump --shutdown" (see pump_shutdown)
  export INCLUDE_SERVER_PID=$(cat "$pid_file")
}


pump_shutdown() {
  # TODO add a separator line to the stdout/stderr or rotate logs
  pump --shutdown | grep -v '___Shutting down' || true
  # The $INCLUDE_SERVER_PORT socket and $INCLUDE_SERVER_DIR directory are removed by pump
  unset INCLUDE_SERVER_DIR INCLUDE_SERVER_PORT INCLUDE_SERVER_PID
}


setup_distcc_hosts() {
  # TODO setup_distcc_hosts is slow when outside CERN.
  # Consider doing port forwarding it a distcc wrapper.

  local distcc_env
  if ! distcc_env=$("$DIR/setup-distcc.py"); then
    return 1
  fi
  eval $distcc_env
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
      # distcc uses TMPDIR for temporary files, which is set above

      export DISTCC_FALLBACK=0  # disable fallbacks and fail
      export DISTCC_BACKOFF_PERIOD=0  # disable backoff
      # stop on include server failure rather than preprocess locally
      # export DISTCC_TESTING_INCLUDE_SERVER=1  # undocumented variable
      export BUILDFLAGS="$BUILDFLAGS -j1"  # one job at a time
    fi
  else
    log ERROR "Failed to set up hosts for distcc"
    exit 1
  fi
}

# Disable distcc if all targets do not cause compilation
if [ "$USE_DISTCC" = true ]; then
  USE_DISTCC=false
  for TARGET in "$@"; do
    if [[ ! "purge clean configure test" =~ (^|[[:space:]])"$TARGET"($|[[:space:]]) ]]; then
      USE_DISTCC=true
    fi
  done
fi

# Disable distcc when there are few cxx to build.
# This saves the overheads when iterating on some file.
if [ "$USE_DISTCC" = true -a "$DEBUG_DISTCC" != true ]; then
  if [ -f "$BUILD_PATH/$PROJECT/build.$BINARY_TAG/build.ninja" ]; then
    ninja_todo=$("$CONTRIB/bin/ninja" -C "$BUILD_PATH/$PROJECT/build.$BINARY_TAG" -n | \
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

compile_commands_src="$BUILD_PATH/$PROJECT/build.$BINARY_TAG/compile_commands.json"
compile_commands_dst="$OUTPUT/$PROJECT/compile_commands.json"
runtime_env_src="$BUILD_PATH/$PROJECT/build.$BINARY_TAG/python.env"
runtime_env_dst="$OUTPUT/$PROJECT/runtime.env"
runtime_env_dst2="$PROJECT/.env"  # needed for Python debugging config

# Check build-env to see why we set CMAKE_PREFIX_PATH here.
# LBENV_CURRENT_WORKSPACE is only considered if it's in CMAKE_PREFIX_PATH
# (see https://gitlab.cern.ch/lhcb-core/lcg-toolchains/-/issues/8).
# Also, it is useful to have the stack directory so that we can automatically
# override things like lcg-toolchains.
export CMAKE_PREFIX_PATH="$LBENV_CURRENT_WORKSPACE:$cmakePrefixPath"
printenv | sort > "$OUTPUT/project.mk.env"
if [ "$PROJECT" = monohack ]; then  # FIXME this is a hack for the cmake wrapper!
  "$@"
else
  if [ -n "$targetBuildPath" ]; then
    # We need to "symlink" the build directory because otherwise ccache keys would always
    # contain /home/username (the source and the build have a different base and base_dir is not enough).
    # For a comparison of various options, see
    #     https://web.archive.org/web/20161124231755/http://www.redbottledesign.com/blog/mirroring-files-different-places-links-bind-mounts-and-bindfs
    # We can't really use symlinking
    #    ln -sTf "$targetBuildPath/$PROJECT/build.$BINARY_TAG" "$BUILD_PATH/$PROJECT/build.$BINARY_TAG"
    # because that doesn't work with cmake:
    #     https://discourse.cmake.org/t/symlinks-on-macos-can-result-in-error-still-dirty-after-100-tries-when-using-ninja/3647
    # Instead, resort to bindfs, if available:
    mkdir -p "$targetBuildPath/$PROJECT/build.$BINARY_TAG" "$BUILD_PATH/$PROJECT/build.$BINARY_TAG"
    findmnt "$BUILD_PATH/$PROJECT/build.$BINARY_TAG" >/dev/null \
      || (
        ulimit -Sn $(ulimit -Hn);
        bindfs --multithreaded "$targetBuildPath/$PROJECT/build.$BINARY_TAG" "$BUILD_PATH/$PROJECT/build.$BINARY_TAG";
      )
  fi

  make -f "$DIR/project.mk" -C "$PROJECT" "BUILDDIR=$BUILD_PATH/$PROJECT/build.$BINARY_TAG" "$@"
fi
# cd "$BUILD_PATH/$PROJECT/build.$BINARY_TAG" && ninja $BUILDFLAGS "$@" && cd -
# TODO catch CTRL-C during make here and do the clean up, see
#      https://unix.stackexchange.com/questions/163561/control-which-process-gets-cancelled-by-ctrlc

###########################################################
# clean up
###########################################################
if [ "$USE_DISTCC" = true ]; then
  if [ "$USE_DISTCC_PUMP" = true ]; then
    pump_shutdown
  fi
fi
if [ "$USE_CCACHE" = true ]; then
  ccache --show-log-stats -v | grep -v ' 0$'
fi

# Create symlinks if building outside of stack
# rel_build_dir=$PROJECT/build.$BINARY_TAG
# rel_install_area=$PROJECT/InstallArea/$BINARY_TAG
# if [ ! $BUILD_PATH/$rel_build_dir -ef $rel_build_dir ]; then
#   if [ -d $rel_build_dir ]; then
#     if [ -d $rel_build_dir -a ! \( -L $rel_build_dir \) ]; then
#       log ERROR "Please delete existing directory $rel_build_dir"
#     fi
#     ln -sTf $BUILD_PATH/$rel_build_dir $rel_build_dir || true
#   fi
#   if [ -d $BUILD_PATH/$rel_install_area ]; then
#     mkdir -p $PROJECT/InstallArea
#     if [ -d $rel_install_area -a ! \( -L $rel_install_area \) ]; then
#       log ERROR "Please delete existing directory $rel_install_area"
#     fi
#     ln -sTf $BUILD_PATH/$rel_install_area $rel_install_area || true
#   fi
# fi

# Copy compile commands and runtime environment if changed
cmp --silent "$compile_commands_src" "$compile_commands_dst" \
  || cp -f "$compile_commands_src" "$compile_commands_dst" 2>/dev/null \
  || true
run_cmd="$BUILD_PATH/$PROJECT/build.$BINARY_TAG/run"
if [ -f $run_cmd ]; then
  # TODO the following costs about 0.2s, should only run it if the xenv changed
  # Filter out PYTHONHOME to workaround an issue in the VSCode python extension,
  # where the python interpreter is run in the wrong .env and causes a SIGABRT.
  if ( $run_cmd env 2>/dev/null | grep -v '^PYTHONHOME=' >"$runtime_env_src" ) ; then
    if ! cmp --silent "$runtime_env_src" "$runtime_env_dst" ; then
      cp -f "$runtime_env_src" "$runtime_env_dst" 2>/dev/null || true
    fi
    if ! cmp --silent "$runtime_env_src" "$runtime_env_dst2" ; then
      cp -f "$runtime_env_src" "$runtime_env_dst2" 2>/dev/null || true
    fi
  fi
fi
