# preamble
cmake_minimum_required(VERSION 3.15)
project(mono VERSION 1.0 LANGUAGES CXX)
include(CTest)

set(root_path ${CMAKE_SOURCE_DIR}/..)

define_property(GLOBAL PROPERTY project_deps_p BRIEF_DOCS "internal" FULL_DOCS "internal")
set_property(GLOBAL PROPERTY project_deps_p "")
define_property(GLOBAL PROPERTY project_deps_dep BRIEF_DOCS "internal" FULL_DOCS "internal")
set_property(GLOBAL PROPERTY project_deps_dep "")


# Override lhcb_find_package to not lookup projects
# The check for a mono build does not work here.
macro(lhcb_find_package project)
    # collect project dependencies
    set_property(GLOBAL APPEND PROPERTY project_deps_p ${PROJECT_NAME})
    set_property(GLOBAL APPEND PROPERTY project_deps_dep ${project})
endmacro()

# TODO wrap lhcb_finalize_configuration and define ${project}_all target to really depend on all targets

include($ENV{OUTPUT_PATH}/mono_projects.cmake)
list(JOIN PROJECTS " " _projects_msg)
message(STATUS "Building ${_projects_msg}")

# special cases
list(PREPEND CMAKE_MODULE_PATH ${root_path}/LHCb/Phys/LoKiCore/cmake)
list(PREPEND CMAKE_MODULE_PATH ${root_path}/Gaudi/cmake/modules)
# loop over the projects
execute_process(COMMAND date +%s OUTPUT_VARIABLE start_time)
foreach(project IN LISTS PROJECTS)
    message(STATUS "========== ${project} ==========")
    execute_process(COMMAND date +%s OUTPUT_VARIABLE p_start_time)

    add_subdirectory(${root_path}/${project} ${project}) # use EXCLUDE_FROM_ALL?
    add_custom_target(${project}_all ALL)
    foreach(merge_target MergeComponents;MergeRootmaps;MergeConfdb;MergeConfDB2)
        if (TARGET ${project}_${merge_target})
            add_dependencies(${project}_all ${project}_${merge_target})
        endif()
    endforeach()

    execute_process(COMMAND date +%s OUTPUT_VARIABLE p_end_time)
    math(EXPR time_delta "${p_end_time} - ${p_start_time}")
    message(STATUS "========== ${project} configured in ${time_delta}s ==========")
    list(PREPEND CMAKE_MODULE_PATH ${root_path}/${project}/cmake)
endforeach()

math(EXPR time_delta "${p_end_time} - ${start_time}")
message(STATUS "========== Everything configured in ${time_delta}s ==========")

# add dependencies between Project_all targets
get_property(project_deps_p GLOBAL PROPERTY project_deps_p)
get_property(project_deps_dep GLOBAL PROPERTY project_deps_dep)
foreach(project dep IN ZIP_LISTS project_deps_p project_deps_dep)
    add_dependencies(${project}_all ${dep}_all)
endforeach()
