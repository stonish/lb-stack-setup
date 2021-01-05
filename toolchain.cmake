CMAKE_MINIMUM_REQUIRED(VERSION 3.18)

# Use our wrapper script to launch compilations (directly, via ccache and/or distcc)
set(compiler_launcher "${CMAKE_CURRENT_LIST_DIR}/compile.sh")
set(CMAKE_C_COMPILER_LAUNCHER "${compiler_launcher}" CACHE FILEPATH "lb-stack-setup override")
set(CMAKE_CXX_COMPILER_LAUNCHER "${compiler_launcher}" CACHE FILEPATH "lb-stack-setup override")

# Make sure the LbDevTools old-style toolchain does not enable CMAKE_USE_CCACHE,
# which resorts RULE_LAUNCH_COMPILE. Instead we use CMAKE_<LANG>_COMPILER_LAUNCHER
set(CMAKE_USE_CCACHE OFF CACHE BOOL "lb-stack-setup override")

# Colourful compiler errors
# - old-style CMake
set(GAUDI_DIAGNOSTICS_COLOR ON CACHE BOOL "lb-stack-setup override")
# - new CMake
set(LCG_DIAGNOSTICS_COLOR ON CACHE BOOL "lb-stack-setup override")

# Do not build Gaudi OpenCL examples as distcc servers may not have it installed
# (old-style CMake)
set(CMAKE_DISABLE_FIND_PACKAGE_OpenCL ON)
# TODO only for legacy versions of Gaudi

# Force version of LCG (old-style CMake)
# - set HEPTOOLS_VERSION env variable to override the default in Gaudi's toolchain
set(ENV{HEPTOOLS_VERSION} $ENV{LCG_VERSION})
# - set heptools_version variable so that downstream projects do not try to guess
set(heptools_version $ENV{LCG_VERSION})

set(GAUDI_USE_INTELAMPLIFIER OFF CACHE BOOL "lb-stack-setup override")
set(GAUDI_LEGACY_CMAKE_SUPPORT ON CACHE BOOL "lb-stack-setup override")

# This toolchain file is included multiple times. While the first include is
# "clean" , subsequent includes can (will) have the environment changed such
# that we cannot call the python 3 config.py (e.g. the lcg toolchain sets
# PYTHONHOME). Because of this we guard the logic with a variable.
# More about inclusion order at https://stackoverflow.com/questions/30503631
if(NOT DEFINED _LBSTACK_PROCESSED)
  # this check is needed because the toolchain is called when checking the
  # compiler (without the proper cache)
  if(NOT CMAKE_SOURCE_DIR MATCHES "CMakeTmp")
    # Set CMAKE_PREFIX_PATH environment variable
    execute_process(
      COMMAND ${CMAKE_CURRENT_LIST_DIR}/config.py cmakePrefixPath
      OUTPUT_VARIABLE _cmake_prefix_path_colons
      OUTPUT_STRIP_TRAILING_WHITESPACE)

    # Confusingly, Gaudi uses the environment variable CMAKE_PREFIX_PATH
    # to populate the cmake variable CMAKE_PREFIX_PATH, so we play along.
    set(ENV{CMAKE_PREFIX_PATH} "${_cmake_prefix_path_colons}")
    # Note that the cmakePrefixPath settings typically contains the
    # $CMAKE_PREFIX_PATH that comes from LbEnv.

    # Limit parallelism of non-distributable jobs
    execute_process(
      COMMAND ${CMAKE_CURRENT_LIST_DIR}/config.py localPoolDepth
      OUTPUT_VARIABLE _local_pool_depth
      OUTPUT_STRIP_TRAILING_WHITESPACE)
    set_property(GLOBAL APPEND PROPERTY JOB_POOLS local_pool=${_local_pool_depth})
    set(CMAKE_JOB_POOL_LINK local_pool)
    set(GENREFLEX_JOB_POOL local_pool)
  endif()
  set(_LBSTACK_PROCESSED TRUE)
endif()


# Delegate to a toolchain.cmake in the project or the default
find_file(lbdevtools_toolchain NAMES toolchain.cmake PATH_SUFFIXES ..)
if(EXISTS ${CMAKE_SOURCE_DIR}/toolchain.cmake)
  message(STATUS "Delegating to project-specific toolchain at ${CMAKE_SOURCE_DIR}/toolchain.cmake")
  # in this case the project toolchain should delegate to the default
  include(${CMAKE_SOURCE_DIR}/toolchain.cmake)
else()
  if(lbdevtools_toolchain)
    message(STATUS "Delegating to default toolchain at ${lbdevtools_toolchain}")
    include(${lbdevtools_toolchain})
  else()
    message(FATAL_ERROR "Cannot find default toolchain.cmake (from LbDevTools)")
  endif()
endif()
