DIR := $(abspath $(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

# record the environment we're executed in
_output_path := $(shell "$(DIR)/config.py" outputPath)
_dummy := $(shell mkdir -p "$(_output_path)" && printenv | sort > "$(_output_path)/host.env")

# settings
include $(DIR)/configuration.mk

# default target
all:

GIT_BASE := $(or $(GIT_BASE),https://gitlab.cern.ch)

# separate branch (or tag) from project/branch
project = $(firstword $(subst /, ,$1))
branch = $(or $(word 2,$(subst /, ,$1)),$(value 2))
$(foreach p,$(PROJECTS),$(eval $(call project,$(p))_BRANCH := $(call branch,$(p),$($(p)_BRANCH))))
PROJECTS := $(foreach p,$(PROJECTS),$(call project,$(p)))

# main targets
all: build

checkout: $(patsubst %,%-checkout,$(PROJECTS))
	@echo "checkout completed"
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

help:
	@for t in $(ALL_TARGETS) ; do echo .. $$t ; done

# public targets: main targets
ALL_TARGETS = all build checkout clean purge use-git-https use-git-ssh use-git-krb5

# ----------------------
# implementation details
# ----------------------
# remove unsatisfiable dependencies
$(foreach p,$(PROJECTS),$(eval $(p)_DEPS := $(filter $($(p)_DEPS), $(PROJECTS))))
# compute inverse deps for "clean" targets
$(foreach p,$(PROJECTS),$(foreach d,$($(p)_DEPS),$(eval $(d)_INV_DEPS += $(p))))
# public targets: project targets
ALL_TARGETS += $(foreach p,$(PROJECTS),$(p) $(p)-checkout $(p)-clean $(p)-purge fast/$(p) fast/$(p)-clean)

define PROJECT_settings
# project settings
$(1)_GITGROUP := $$(or $$($(1)_GITGROUP),lhcb)
$(1)_URL := $$(or $$($(1)_URL),$(GIT_BASE)/$$($(1)_GITGROUP)/$(1).git)
$(1)_BRANCH := $$(or $$($(1)_BRANCH),$(DEFAULT_BRANCH))
# checkout
$(1)-checkout:
	@test -e $(1) || git clone --recurse-submodules -b $$($(1)_BRANCH) $$($(1)_URL) $(1)
# TODO the following is executed every time because $(1)-checkout is phony
$(1)/run: $(1)-checkout $(DIR)/project-run.sh
	@ln -sf $(DIR)/project-run.sh $(1)/run
	@grep -Fxq "run" $(1)/.git/info/exclude || echo "run" >> $(1)/.git/info/exclude
# generic build target
$(1)/%: $$($(1)_DEPS) fast/$(1)/% ;
fast/$(1)/%: $(1)-checkout $(1)/run
	@$(DIR)/build-env $(DIR)/make.sh $(1) $$*
# exception for purge and clean: always do fast/Project/purge or clean
$(1)/purge: fast/$(1)/purge ;
$(1)/clean: fast/$(1)/clean ;
# build... delegate to generic target
$(1): $(1)/install
fast/$(1): fast/$(1)/install
# clean
$(1)-clean: $(patsubst %,%-clean,$($(1)_INV_DEPS))
	$$(MAKE) -C fast/$(1)-clean
fast/$(1)-clean:
	@test -d $(1)/build.$$(CMTCONFIG) && $$(MAKE) $(1)/clean || true
	$(RM) -r $(1)/InstallArea/$$(CMTCONFIG)
# purge
$(1)-purge:
	@test -e $(1) && $$(MAKE) fast/$(1)/purge || true
endef
$(foreach proj,$(PROJECTS),$(eval $(call PROJECT_settings,$(proj))))

set-git-remote-url:
	@$(foreach p,$(PROJECTS),if [ -d $p ] ; then ( cd $p && pwd && git remote set-url origin $(GIT_BASE)/$($p_GITGROUP)/$p.git && git remote -v ) ; fi ;)

.PHONY: $(ALL_TARGETS)

# debugging
# print-%  : ; @echo $* = $($*)
