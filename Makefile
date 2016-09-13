# settings
CONFIGFILE = Future.py
CCACHE := $(shell which ccache 2> /dev/null)
ifeq ($(CCACHE),)
  CCACHE := $(shell which ccache-swig 2> /dev/null)
endif

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
ifeq (,$(filter pull-build deep-purge update checkout,$(MAKECMDGOALS)))
.dependencies.mk: $(CONFIGFILE) gen_make_deps.py .checkout.stamp
	python gen_make_deps.py $@
-include .dependencies.mk
endif

# main targets
.PHONY: all checkout update build clean purge $(PROJECTS) $(patsubst %,%-clean,$(PROJECTS)) $(patsubst %,%-purge,$(PROJECTS))
all: build
checkout: .checkout.stamp
	@echo "checkout completed"
update:
	$(RM) .checkout.stamp
	$(MAKE) .checkout.stamp
	@echo "update completed"
build: $(PROJECTS) checkout
clean: $(patsubst %,%-clean,$(PROJECTS))
purge: $(patsubst %,%-purge,$(PROJECTS))
deep-purge:
	$(RM) -r $(PROJECTS_UPCASE) .setup.mk .definitions.mk .dependencies.mk .checkout.stamp


# distribution
PRE_BUILT_IMAGE := $(shell git describe --match "hackathon-*" --abbrev=0 --tags).tar.xz
$(PRE_BUILT_IMAGE): build
	tar -c --xz -f $@ .ccache $(PROJECTS_UPCASE)
dist: $(PRE_BUILT_IMAGE)
pull-build:
	curl http://lhcbproject.web.cern.ch/lhcbproject/dist/$(PRE_BUILT_IMAGE) | tar -x --xz -f -
	touch .checkout.stamp


# implementation details
.checkout.stamp: checkout.py $(CONFIGFILE)
	python checkout.py
	touch .checkout.stamp

ifneq ($(CCACHE),)
$(CCACHE_DIR):
	$(CCACHE) -F 20000 -M 0

$(PROJECTS): $(CCACHE_DIR)
endif
