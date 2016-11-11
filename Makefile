# settings
include configuration.mk

# default target
all:

# environment
.setup.mk: setup.sh
	sed 's/=/:=/' $^ > $@
-include .setup.mk

# main targets
all: build
.git-setup.stamp:
	@if [ -z $$(git config --global user.email) ] ; then \
		echo "warning: setting dummy user.email for Git to noreply-lhcb-upgrade-hackathon@cern.ch" ; \
		git config --global user.email "noreply-lhcb-upgrade-hackathon@cern.ch" ; \
	fi
	@if [ -z $$(git config --global user.name) ] ; then \
		echo "warning: setting dummy user.name for Git to $$USER" ; \
		git config --global user.name "$$USER" ; \
	fi
	@touch $@

checkout: $(patsubst %,%-checkout,$(PROJECTS))
	@echo "checkout completed"
update: checkout $(patsubst %,%-update,$(PROJECTS))
	@echo "update completed"
build: $(PROJECTS)
clean: $(patsubst %,%-clean,$(PROJECTS))
purge: $(patsubst %,%-purge,$(PROJECTS))
deep-purge:
	$(RM) -r $(PROJECTS) .setup.mk

help:
	@for t in $(ALL_TARGETS) ; do echo .. $$t ; done

# public targets: main targets
ALL_TARGETS = all build checkout update clean purge deep-purge

# distribution
PRE_BUILT_IMAGE := $(shell git describe --match "hackathon-*" --abbrev=0 --tags).tar.xz
$(PRE_BUILT_IMAGE):
	$(MAKE) build
	$(MAKE) build
	tar -c --xz -f $@ .ccache $(PROJECTS)
dist: $(PRE_BUILT_IMAGE)
pull-build: .git-setup.stamp
	curl http://lhcbproject.web.cern.ch/lhcbproject/dist/$(PRE_BUILT_IMAGE) | tar -x --xz -f -
	# tar -x --xz -f $(PRE_BUILT_IMAGE)

# ----------------------
# implementation details
# ----------------------
# compute inverse deps for "clean" targets
$(foreach p,$(PROJECTS),$(foreach d,$($(p)_DEPS),$(eval $(d)_INV_DEPS += $(p))))
# public targets: project targets
ALL_TARGETS += $(foreach p,$(PROJECTS),$(p) $(p)-checkout $(p)-update $(p)-clean $(p)-purge fast/$(p) fast/$(p)-clean)

define PROJECT_settings
# project settings
$(1)_URL := $$(if $$($(1)_URL),$$($(1)_URL),https://gitlab.cern.ch/lhcb/$(1).git)
$(1)_BRANCH := $$(if $$($(1)_BRANCH),$$($(1)_BRANCH),$(DEFAULT_BRANCH))
# checkout/update
$(1)-checkout:
	@test -e $(1) || git clone -b $$($(1)_BRANCH) $$($(1)_URL) $(1)
	@cd $(1) && lb-project-init
	@test -h $(1)/run -o -e $(1)/run || ln -s build.$$(CMTCONFIG)/run $(1)/run
$(1)-update: $(1)-checkout
	@cd $(1) && git pull origin $$($(1)_BRANCH)
# generic build target
$(1)/%: $(1)-checkout $$($(1)_DEPS)
	$$(MAKE) -C $(1) $$*
fast/$(1)/%: $(1)-checkout
	$$(MAKE) -C $(1) $$*
# build... delegate to generic target
$(1): $(1)/install
fast/$(1): fast/$(1)/install
# clean
$(1)-clean: $(patsubst %,%-clean,$($(1)_INV_DEPS))
	$$(MAKE) -C fast/$(1)-clean
fast/$(1)-clean:
	-test -d $(1)/build.$$(CMTCONFIG) && $$(MAKE) $(1)/clean
	$(RM) -r $(1)/InstallArea/$$(CMTCONFIG)
# purge
$(1)-purge:
	-test -e $(1) && $$(MAKE) fast/$(1)/purge
endef
$(foreach proj,$(PROJECTS),$(eval $(call PROJECT_settings,$(proj))))

CCACHE := $(shell which ccache 2> /dev/null)
ifeq ($(CCACHE),)
  CCACHE := $(shell which ccache-swig 2> /dev/null)
endif
ifneq ($(CCACHE),)
$(CCACHE_DIR):
	$(CCACHE) -F 20000 -M 0
$(PROJECTS): $(CCACHE_DIR)
endif

.PHONY: $(ALL_TARGETS) dist pull-build
