# settings
include configuration.mk

# default target
all:

CCACHE_DIR := $(shell . `pwd`/setup.sh; echo $${CCACHE_DIR})

GIT_BASE := $(or $(GIT_BASE),https://gitlab.cern.ch)

# separate branch (or tag) from project/branch
project = $(firstword $(subst /, ,$1))
branch = $(or $(word 2,$(subst /, ,$1)),$(value 2))
$(foreach p,$(PROJECTS),$(eval $(call project,$(p))_BRANCH := $(call branch,$(p),$($(p)_BRANCH))))
PROJECTS := $(foreach p,$(PROJECTS),$(call project,$(p)))

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
use-git-https:
	@$(MAKE) set-git-remote-url GIT_BASE=https://gitlab.cern.ch
use-git-ssh:
	@$(MAKE) set-git-remote-url GIT_BASE=ssh://git@gitlab.cern.ch:7999
use-git-krb5:
	@$(MAKE) set-git-remote-url GIT_BASE=https://:@gitlab.cern.ch:8443

CMD = true
for-each:
	@for p in $(PROJECTS) ; do if [ -d $$p ] ; then ( cd $$p && pwd && $(CMD) ) ; fi ; done

build: $(PROJECTS)
clean: $(patsubst %,%-clean,$(PROJECTS))
purge: $(patsubst %,%-purge,$(PROJECTS))
deep-purge:
	$(RM) -r $(PROJECTS)

help:
	@for t in $(ALL_TARGETS) ; do echo .. $$t ; done

# public targets: main targets
ALL_TARGETS = all build checkout update clean purge deep-purge use-git-https use-git-ssh use-git-krb5

# distribution
DIST_TAG := $(or $(DIST_TAG),$(shell git describe --match "*" --abbrev=0 --tags 2> /dev/null))
ifneq ($(DIST_TAG),)
PRE_BUILT_IMAGE := $(DIST_TAG).$(CMTCONFIG).tar.xz
$(PRE_BUILT_IMAGE):
	$(MAKE) build
	$(MAKE) build
	tar -c --xz -f $@ .ccache $(PROJECTS)
dist: $(PRE_BUILT_IMAGE)
pull-build: .git-setup.stamp
	curl http://lhcbproject.web.cern.ch/lhcbproject/dist/$(PRE_BUILT_IMAGE) | tar -x --xz -f -
endif

# ----------------------
# implementation details
# ----------------------
# remove unsatisfiable dependencies
$(foreach p,$(PROJECTS),$(eval $(p)_DEPS := $(filter $($(p)_DEPS), $(PROJECTS))))
# compute inverse deps for "clean" targets
$(foreach p,$(PROJECTS),$(foreach d,$($(p)_DEPS),$(eval $(d)_INV_DEPS += $(p))))
# public targets: project targets
ALL_TARGETS += $(foreach p,$(PROJECTS),$(p) $(p)-checkout $(p)-update $(p)-clean $(p)-purge fast/$(p) fast/$(p)-clean)

define PROJECT_settings
# project settings
$(1)_GITGROUP := $$(or $$($(1)_GITGROUP),lhcb)
$(1)_URL := $$(or $$($(1)_URL),$(GIT_BASE)/$$($(1)_GITGROUP)/$(1).git)
$(1)_BRANCH := $$(or $$($(1)_BRANCH),$(DEFAULT_BRANCH))
# checkout/update
$(1)-checkout:
	@test -e $(1) || git clone -b $$($(1)_BRANCH) $$($(1)_URL) $(1)
	@cd $(1) && lb-project-init
	@grep -Fxq "toolchain.cmake" $(1)/.git/info/exclude || echo "toolchain.cmake" >> $(1)/.git/info/exclude
	@test -h $(1)/run -o -e $(1)/run || (\
		echo -e '#!/bin/bash\n$$$$(dirname "$$$${BASH_SOURCE[0]}")/build.$$$${CMTCONFIG}/run "$$$$@"' > $(1)/run && \
		chmod +x $(1)/run)
	@grep -Fxq "run" $(1)/.git/info/exclude || echo "run" >> $(1)/.git/info/exclude
$(1)-update: $(1)-checkout
	@cd $(1) && git pull origin $$($(1)_BRANCH)
# generic build target
$(1)/%: $$($(1)_DEPS) fast/$(1)/% ;
fast/$(1)/%: $(1)-checkout setup.sh
	@(. `pwd`/setup.sh -m $(1); (set -v ; $$(MAKE) -C $(1) $$*); `pwd`/setup.sh -s)
# exception for Project/purge: always do fast/Project/purge
$(1)/purge: fast/$(1)/purge setup.sh ;
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
ifeq ($(CCACHE),)
  CCACHE := $(shell lb-run --ext ccache LCG/latest which ccache)
endif
ifneq ($(CCACHE),)
$(CCACHE_DIR):
	$(CCACHE) -F 20000 -M 0
$(PROJECTS): $(CCACHE_DIR)
endif

set-git-remote-url:
	@$(foreach p,$(PROJECTS),if [ -d $p ] ; then ( cd $p && pwd && git remote set-url origin $(GIT_BASE)/$($p_GITGROUP)/$p.git && git remote -v ) ; fi ;)

.PHONY: $(ALL_TARGETS) dist pull-build
