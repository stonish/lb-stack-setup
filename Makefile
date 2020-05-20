DIR := $(abspath $(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

ifeq (${DIR}, ${CURDIR})
  $(error do not run make inside ${DIR})
endif

# default target
all:

# clone projects, write project settings .mk file and source it
# also defines build target
include $(shell "$(DIR)/setup-make.py" $(MAKECMDGOALS))

# main targets
all: build

CMD = true
for-each:
	@for p in $(REPOS) ; do if [[ -d $$p && ! " $(EXCLUDE) " == *" $$p "*  ]] ; then ( cd $$p && pwd && $(CMD) ) ; fi ; done

CONTRIB_DEPS := $(CONTRIB_PATH)/bin/.cmake_timestamp $(CONTRIB_PATH)/bin/ninja $(CONTRIB_PATH)/bin/ccache $(CONTRIB_PATH)/bin/distcc
CONTRIB_DEPS += $(CONTRIB_PATH)/bin/ninjatracing $(CONTRIB_PATH)/bin/post_build_ninja_summary.py
contrib: $(CONTRIB_DEPS)
$(CONTRIB_PATH)/bin/% $(CONTRIB_PATH)/bin/.%_timestamp: $(DIR)/install-%.sh
	@"${DIR}/build-env" bash "$<"
$(CONTRIB_PATH)/bin/ninjatracing $(CONTRIB_PATH)/bin/post_build_ninja_summary.py: $(DIR)/install-tools.sh
	@"${DIR}/build-env" bash "$<"

clean: $(patsubst %,%-clean,$(PROJECTS))
purge: $(patsubst %,%/purge,$(PROJECTS))

help:
	@for t in $(ALL_TARGETS) ; do echo .. $$t ; done

# public targets: main targets
ALL_TARGETS = all build clean purge contrib

# ----------------------
# implementation details
# ----------------------

# public targets: project targets
ALL_TARGETS += $(foreach p,$(PROJECTS),$(p) $(p)-clean fast/$(p) fast/$(p)-clean)

define PROJECT_settings
$(1)/run: $(DIR)/project-run.sh
	@ln -sf $(DIR)/project-run.sh $(1)/run
	@grep -Fxq "run" $(1)/.git/info/exclude || echo "run" >> $(1)/.git/info/exclude
# generic build target
$(1)/%: $$($(1)_DEPS) fast/$(1)/% ;
fast/$(1)/%: $(1)/run $(CONTRIB_DEPS)
	@$(DIR)/build-env $(DIR)/make.sh $(1) $$*
# check kerberos token when running tests
fast/$(1)/test: $(1)/run $(CONTRIB_DEPS)
	@$(DIR)/build-env --check-kerberos $(DIR)/make.sh $(1) test
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
endef
$(foreach proj,$(PROJECTS),$(eval $(call PROJECT_settings,$(proj))))

# stack.code-workspace is always remade by setup-make.py, so this is just
# to avoid the message "Nothing to be done for `stack.code-workspace'"
stack.code-workspace:
	@ # noop command

.PHONY: $(ALL_TARGETS) stack.code-workspace

# ignore -j flag and run serially
.NOTPARALLEL:

# debugging
# print-%  : ; @echo $* = $($*)
