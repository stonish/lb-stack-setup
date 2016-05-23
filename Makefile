# settings
CONFIGFILE = Future.py
export CCACHE_DIR=$(PWD)/.ccache
export CMAKEFLAGS=-DCMAKE_USE_CCACHE=ON
export CMAKE_PREFIX_PATH:=$(PWD):$(CMAKE_PREFIX_PATH)
export VERBOSE=

# generated chunks
# - variables and build rules
.definitions.mk: $(CONFIGFILE) gen_make_definitions.py
	python gen_make_definitions.py $@
-include .definitions.mk
# - dependencies between projects
.dependencies.mk: $(CONFIGFILE) gen_make_deps.py .checkout.stamp
	python gen_make_deps.py $@
-include .dependencies.mk


# main targets
.PHONY: all checkout build clean purge $(PROJECTS)
all: build
checkout: .checkout.stamp
build: $(PROJECTS)
clean:
	for d in $(PROJECTS_DIRS) ; do (test -d  $$d/build.$(CMTCONFIG) && $(MAKE) -C $$d clean ; $(RM) -r $$d/InstallArea) ; done
purge:
	$(RM) -r $(PROJECTS_UPCASE) .definitions.mk .dependencies.mk .checkout.stamp


# distribution
PRE_BUILT_IMAGE = hackaton-201605.tar.xz
$(PRE_BUILT_IMAGE): build
	tar -c --xz -f $@ .ccache $(PROJECTS_UPCASE) .definitions.mk .dependencies.mk .checkout.stamp
dist: $(PRE_BUILT_IMAGE)
pull-build:
	curl http://lhcbproject.web.cern.ch/lhcbproject/dist/$(PRE_BUILT_IMAGE) | tar -x --xz -f -


# implementation details
.checkout.stamp: checkout.py $(CONFIGFILE)
	python checkout.py
	touch .checkout.stamp
