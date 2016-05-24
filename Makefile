# settings
CONFIGFILE = Future.py

# default target
all:

# generated chunks
# - environment
.setup.mk: setup.sh
	sed 's/=/:=/' $^ > $@
-include .setup.mk
# - variables and build rules
.definitions.mk: $(CONFIGFILE) gen_make_definitions.py
	python gen_make_definitions.py $@
-include .definitions.mk
# - dependencies between projects (unless we are pulling the build)
ifeq (,$(filter pull-build clean purge,$(MAKECMDGOALS)))
.dependencies.mk: $(CONFIGFILE) gen_make_deps.py .checkout.stamp
	python gen_make_deps.py $@
-include .dependencies.mk
endif

# main targets
.PHONY: all checkout build clean purge $(PROJECTS)
all: build
checkout: .checkout.stamp
build: $(PROJECTS) checkout
clean:
	for d in $(PROJECTS_DIRS) ; do (test -d  $$d/build.$(CMTCONFIG) && $(MAKE) -C $$d clean ; $(RM) -r $$d/InstallArea) ; done
purge:
	$(RM) -r $(PROJECTS_UPCASE) .setup.mk .definitions.mk .dependencies.mk .checkout.stamp


# distribution
PRE_BUILT_IMAGE = hackaton-201605.tar.xz
$(PRE_BUILT_IMAGE): build
	tar -c --xz -f $@ .ccache $(PROJECTS_UPCASE) .setup.mk .definitions.mk .dependencies.mk .checkout.stamp
dist: $(PRE_BUILT_IMAGE)
pull-build:
	curl http://lhcbproject.web.cern.ch/lhcbproject/dist/$(PRE_BUILT_IMAGE) | tar -x --xz -f -


# implementation details
.checkout.stamp: checkout.py $(CONFIGFILE)
	python checkout.py
	touch .checkout.stamp

$(CCACHE_DIR):
	ccache -F 20000 -M 0

$(PROJECTS): $(CCACHE_DIR)
