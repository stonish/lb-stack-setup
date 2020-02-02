DIR := $(abspath $(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

# project settings
include $(shell "$(DIR)/setup-make.py")

# default target
all:

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

CONTRIB_DEPS := $(CONTRIB_PATH)/bin/.cmake_timestamp $(CONTRIB_PATH)/bin/ninja $(CONTRIB_PATH)/bin/ccache $(CONTRIB_PATH)/bin/distcc
CONTRIB_DEPS += $(CONTRIB_PATH)/bin/ninjatracing $(CONTRIB_PATH)/bin/post_build_ninja_summary.py
contrib: $(CONTRIB_DEPS)
$(CONTRIB_PATH)/bin/% $(CONTRIB_PATH)/bin/.%_timestamp: $(DIR)/install-%.sh
	@"${DIR}/build-env" --no-kerberos bash "$<"
$(CONTRIB_PATH)/bin/ninjatracing $(CONTRIB_PATH)/bin/post_build_ninja_summary.py: $(DIR)/install-tools.sh
	@"${DIR}/build-env" --no-kerberos bash "$<"

build: $(PROJECTS)
clean: $(patsubst %,%-clean,$(PROJECTS))
purge: $(patsubst %,%-purge,$(PROJECTS))

help:
	@for t in $(ALL_TARGETS) ; do echo .. $$t ; done

# public targets: main targets
ALL_TARGETS = all build checkout clean purge use-git-https use-git-ssh use-git-krb5 contrib

# ----------------------
# implementation details
# ----------------------

# public targets: data package targets
ALL_TARGETS += $(foreach p,$(DATA_PACKAGES),$(p) $(p)-checkout)

define PACKAGE_settings
$(1)-checkout:
# put all packages in DBASE, even those in "PARAM"
	@test -e DBASE/$(1) || ( \
		mkdir -p DBASE && cd DBASE && \
		/cvmfs/lhcb.cern.ch/lib/var/lib/LbEnv/644/stable/x86_64-centos7/bin/git-lb-clone-pkg $(1) \
	)
$(1): $(1)-checkout
endef
$(foreach p,$(DATA_PACKAGES),$(eval $(call PACKAGE_settings,$(p))))


# public targets: project targets
ALL_TARGETS += $(foreach p,$(PROJECTS),$(p) $(p)-checkout $(p)-clean $(p)-purge fast/$(p) fast/$(p)-clean)

define PROJECT_settings
# checkout
$(1)-checkout:
	@test -e $(1) || ( \
		git clone $$($(1)_URL) $(1) && \
		cd $(1) && \
		git checkout $$($(1)_BRANCH) && \
		git submodule update --init --recursive \
	)
# TODO the following is executed every time because $(1)-checkout is phony
$(1)/run: $(1)-checkout $(DIR)/project-run.sh
	@ln -sf $(DIR)/project-run.sh $(1)/run
	@grep -Fxq "run" $(1)/.git/info/exclude || echo "run" >> $(1)/.git/info/exclude
# generic build target
$(1)/%: $(DATA_PACKAGES) $$($(1)_DEPS) fast/$(1)/% ;
fast/$(1)/%: $(1)-checkout $(1)/run $(CONTRIB_DEPS)
	@$(DIR)/build-env $(DIR)/make.sh $(1) $$*
# exception for purge and clean: always do fast/Project/purge or clean
$(1)/purge: fast/$(1)/purge ;
$(1)/clean: fast/$(1)/clean ;
# build... delegate to generic target
$(1): $(1)/install
fast/$(1): fast/$(1)/install
# clean
$(1)-clean: $(patsubst %,%-clean,$($(1)_INV_DEPS))
	$$(MAKE) fast/$(1)-clean
fast/$(1)-clean:
	@test -d $(1)/build.$$(shell "$(DIR)/config.py" binaryTag) && $$(MAKE) $(1)/clean || true
	$(RM) -r $(1)/InstallArea/$$(shell "$(DIR)/config.py" binaryTag)
# purge
$(1)-purge:
	@test -e $(1) && $$(MAKE) fast/$(1)/purge || true
endef
$(foreach proj,$(PROJECTS),$(eval $(call PROJECT_settings,$(proj))))

set-git-remote-url:
	@$(foreach p,$(PROJECTS),if [ -d $p ] ; then ( cd $p && pwd && git remote set-url origin $(GIT_BASE)/$($p_GITGROUP)/$p.git && git remote -v ) ; fi ;)

.PHONY: $(ALL_TARGETS)

# ignore -j flag and run serially
.NOTPARALLEL:

# debugging
# print-%  : ; @echo $* = $($*)
