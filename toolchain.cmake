CMAKE_MINIMUM_REQUIRED(VERSION 3.15)

if(NOT (CMAKE_GENERATOR STREQUAL "Ninja"))
  message(FATAL_ERROR "Only Ninja generator is supported")
endif()

# Make sure cmake will use our own compiler wrapper
set(ccache_cmd ${CMAKE_CURRENT_LIST_DIR}/compile.sh CACHE FILEPATH "")
# TODO This can probably be moved below but atm it does not work
#      as the find_program(ccache_cmd) happens very early in Gaudi.

# this check is needed because the toolchain is called when checking the
# compiler (without the proper cache)
if(NOT CMAKE_SOURCE_DIR MATCHES "CMakeTmp")
  # Specify where our projects are
  execute_process(
    COMMAND ${CMAKE_CURRENT_LIST_DIR}/config.py projectPath
    OUTPUT_VARIABLE _project_path
    OUTPUT_STRIP_TRAILING_WHITESPACE)

  set(CMAKE_PREFIX_PATH ${_project_path} ${CMAKE_PREFIX_PATH})

  # Make sure cmake will use the local install of ninja
  execute_process(
    COMMAND ${CMAKE_CURRENT_LIST_DIR}/config.py contribPath
    OUTPUT_VARIABLE _contrib_path
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  set(CMAKE_MAKE_PROGRAM ${_contrib_path}/bin/ninja CACHE FILEPATH "")

  set(CMAKE_USE_CCACHE ON)  # use compile.sh
  set(GAUDI_DIAGNOSTICS_COLOR ON)  # nicer errors

  # Disable functor cache
  # if [[ " Brunel Moore DaVinci " =~ " $PROJECT " ]]; then
  #   set(LOKI_BUILD_FUNCTOR_CACHE OFF)
  # fi

  # Limit parallelism of non-distributable jobs
  if((CMAKE_VERSION VERSION_GREATER_EQUAL 3.15) AND (CMAKE_GENERATOR STREQUAL "Ninja"))
    execute_process(
        COMMAND ${CMAKE_CURRENT_LIST_DIR}/config.py localPoolDepth
        OUTPUT_VARIABLE _local_pool_depth
        OUTPUT_STRIP_TRAILING_WHITESPACE)

    set_property(GLOBAL PROPERTY JOB_POOLS local_pool=${_local_pool_depth})
    # TODO for some reason this line is executed twice, so we can't APPEND
    set(CMAKE_JOB_POOL_LINK local_pool)
    set(GENREFLEX_JOB_POOL local_pool)
  endif()

  # Delegate to a toolchain.cmake in the project or the default
  if(EXISTS ${CMAKE_SOURCE_DIR}/toolchain.cmake)
    # in this case the project toolchain should delegate to the default
    include(${CMAKE_SOURCE_DIR}/toolchain.cmake)
  else()
    include(${_project_path}/Gaudi/cmake/GaudiDefaultToolchain.cmake)
  endif()

  # Workaround some apparent bug in the detection of genconf.exe --no-init support
  set(GENCONF_WITH_NO_INIT ON)

  # Do not build Gaudi OpenCL examples as distcc servers may not have it installed
  set(CMAKE_DISABLE_FIND_PACKAGE_OpenCL ON)
endif()
