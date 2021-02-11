################################################################################
#
# Generic Makefile to simplify the use of CMake projects
# ------------------------------------------------------
#
# This simple Makefile is meant to provide a simplified entry point for the
# configuration and build of CMake-based projects that use a default toolchain
# (as it is the case for Gaudi-based projects).
#
# Only a few targets are actually provided: all the main targets are directly
# delegated to the CMake Makefile.
#
# Main targets:
#
#     all
#         (default) build everything
#
#     test [*]_
#         run the declared tests
#
#     install
#         populate the InstallArea with the products of the build
#
#     clean
#         remove build products from the build directory
#
#     help
#         print the list of available targets
#
#     configure [*]_
#         alias to CMake 'rebuild_cache' target
#
# :Author: Marco Clemencic
#
# .. [*] Targets defined by this Makefile.
#
################################################################################

# record the environment we're executed in (added by RM)
# note that DIR will end with a /
DIR := $(dir $(lastword $(MAKEFILE_LIST)))
PROJECT := $(notdir $(CURDIR))

# settings
CMAKE := cmake
CTEST := ctest
NINJA := ninja

# modified by RM
ifeq ($(findstring CMAKE_TOOLCHAIN_FILE,$(CMAKEFLAGS)),)
  override CMAKEFLAGS += -DCMAKE_TOOLCHAIN_FILE=$(DIR)toolchain.cmake
endif
ifneq ($(wildcard $(CURDIR)/cache_preload.cmake),)
  override CMAKEFLAGS += -C$(CURDIR)/cache_preload.cmake
endif

ifndef BINARY_TAG
  ifdef CMAKECONFIG
    BINARY_TAG := ${CMAKECONFIG}
  else
    ifdef CMTCONFIG
      BINARY_TAG := ${CMTCONFIG}
    endif
  endif
endif

ifeq ($(BINARY_TAG)$(BUILDDIR),)
$(error one of BINARY_TAG, CMTCONFIG or BUILDDIR must be defined)
endif
BUILDDIR := $(CURDIR)/build.$(BINARY_TAG)
# Added by RM
INSTALLDIR := $(CURDIR)/InstallArea/$(BINARY_TAG)

ifneq ($(wildcard $(BUILDDIR)/Makefile),)
  # force the use of GNU Make if the build was using it
  USE_MAKE := 1
endif
ifneq ($(wildcard $(BUILDDIR)/build.ninja),)
  ifeq ($(NINJA),)
    # make sure we have ninja if we configured with it
    $(error $(BUILDDIR) was configured for Ninja, but it is not in the path)
  endif
endif

ifneq ($(NINJA),)
  ifeq ($(USE_MAKE),)
    USE_NINJA := 1
  endif
endif

# build tool
ifneq ($(USE_NINJA),)
  # enable Ninja
  override CMAKEFLAGS += -GNinja
  BUILD_CONF_FILE := build.ninja
  BUILDFLAGS := $(NINJAFLAGS)
  # no need to pass -v as cmake --build does it when VERBOSE is set
else
  BUILD_CONF_FILE := Makefile
endif
BUILD_CMD := $(CMAKE) --build $(BUILDDIR) --target

# default target
patch-python-ns:

# with the following patching, python modules are imported from the sources
# of dependent projects and not the InstallArea (i.e. no need to rebuild)
patch-python-ns: all
	# Patching python namespaced packages for intellisense support...
	@find $(BUILDDIR) -path '$(BUILDDIR)/python/*/__init__.py' -exec bash -c "\
	  set -euo pipefail; \
	  grep '^fname =' {} \
	  | cat '$(DIR)/python_ns_init_pkgutil.py' - '$(DIR)/python_ns_init_gaudi.py' > '{}.new' \
	  && mv --backup=simple '{}.new' '{}'" \;
	@find $(BUILDDIR) -path '$(BUILDDIR)/*/genConf/*/__init__.py' -exec bash -c \
	  "cp --backup=simple '$(DIR)/python_ns_init_pkgutil.py' '{}'" \;

%: $(BUILDDIR)/$(BUILD_CONF_FILE) FORCE
	+$(BUILD_CMD) $* -- $(BUILDFLAGS)

# aliases
.PHONY: configure test FORCE patch-python-ns  # fixed by RM (tests -> test)
ifneq ($(wildcard $(BUILDDIR)/$(BUILD_CONF_FILE)),)
configure: rebuild_cache
else
configure: $(BUILDDIR)/$(BUILD_CONF_FILE)
endif
	@ # do not delegate further

# This wrapping around the test target is used to ensure the generation of
# the XML output from ctest.
test: $(BUILDDIR)/$(BUILD_CONF_FILE)
	$(RM) -r $(BUILDDIR)/Testing
	-cd $(BUILDDIR) && $(CTEST) -T test $(value ARGS)
	$(RM) -r $(BUILDDIR)/html
	+$(BUILD_CMD) HTMLSummary

ifeq ($(VERBOSE),)
# less verbose install (see GAUDI-1018)
# (emulate the default CMake install target)
install: patch-python-ns
	cd $(BUILDDIR) && $(CMAKE) -P cmake_install.cmake | grep -v "^-- Up-to-date:"
	test -f $(BUILDDIR)/config/$(PROJECT)-build.xenv && cp $(BUILDDIR)/config/$(PROJECT)-build.xenv $(INSTALLDIR)/$(PROJECT).xenv || true
endif

# ensure that the target are always passed to the CMake Makefile
FORCE:
	@ # dummy target

# Makefiles are used as implicit targets in make, but we should not consider
# them for delegation.
$(MAKEFILE_LIST):
	@ # do not delegate further

# trigger CMake configuration
# note that we only fully build the CMAKEFLAGS here in order not to slow down other targets
$(BUILDDIR)/$(BUILD_CONF_FILE):
	mkdir -p $(BUILDDIR)
	cd $(BUILDDIR) && $(CMAKE) $(CMAKEFLAGS) $(shell "$(DIR)config.py" cmakeFlags.default --default '') $(shell "$(DIR)config.py" cmakeFlags.$(PROJECT) --default '') $(CURDIR)
