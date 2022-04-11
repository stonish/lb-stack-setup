DIR := $(abspath $(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

ifeq (${DIR}, ${CURDIR})
  $(error do not run make inside ${DIR})
endif

# default target
all:

ifeq (,$(findstring environment,$(origin BINARY_TAG)))
  # BINARY_TAG was given on the command line (not in the environment).
  # In this case we override the binaryTag setting.
  # The output of setup-make.py below will not reset the value of BINARY_TAG.
  BINARY_TAG_OVERRIDE := $(BINARY_TAG)
endif

# clone projects, write project settings .mk file and source it
# also defines build target
include $(shell "$(DIR)/setup-make.py" $(MAKECMDGOALS))

# main targets
all: build

CMD = true
for-each:
	@for p in $(REPOS) ; do if [[ -d $$p && ! " $(EXCLUDE) " == *" $$p "*  ]] ; then ( cd $$p && pwd && $(CMD) ) ; fi ; done

help:
	@for t in $(sort $(ALL_TARGETS)) ; do echo .. $$t ; done

# public targets: main targets
ALL_TARGETS = all build clean purge update report

ifneq ($(MONO_BUILD),1)

clean: $(patsubst %,%-clean,$(ALL_PROJECTS))
purge: $(patsubst %,%/purge,$(ALL_PROJECTS))

else

# A literal space.
empty :=
space := $(empty) $(empty)

clean:
	@$(DIR)/build-env $(DIR)/make.sh mono clean
purge:
	$(RM) -r $(BUILD_PATH)/mono/build.$(BINARY_TAG) $(BUILD_PATH)/mono/InstallArea/$(BINARY_TAG)
	find mono "(" -name "InstallArea" -prune -o -name "*.pyc" ")" -a -type f -exec $(RM) -v \{} \;
build:
	@$(DIR)/build-env --require-kerberos-distcc $(DIR)/make.sh mono all
configure:
	@$(DIR)/build-env $(DIR)/make.sh mono configure
test:
	@$(DIR)/build-env --check-kerberos $(DIR)/make.sh mono test

ALL_TARGETS += configure test

endif


# ----------------------
# implementation details
# ----------------------

ifneq ($(MONO_BUILD),1)

# use ALL_PROJECTS since these are all possible targets
ALL_TARGETS += $(foreach p,$(ALL_PROJECTS),$(p) $(p)/ $(p)/test fast/$(p) fast/$(p)/test)

define PROJECT_settings
# generic build target
$(1)/%: $$($(1)_DEPS) fast/$(1)/% ;
fast/$(1)/%:
	@$(DIR)/build-env --require-kerberos-distcc $(DIR)/make.sh $(1) $$*
# check kerberos token when running tests
fast/$(1)/test:
	@$(DIR)/build-env --check-kerberos $(DIR)/make.sh $(1) test
$(1)/test: $$($(1)_DEPS) fast/$(1)/test ;
# special checkout targets (noop here, as checkout is done in setup-make.py)
fast/$(1)/checkout: ;@# noop
$(1)/checkout: fast/$(1)/checkout ;
# exception for clean: always do fast/Project/clean
$(1)/clean: fast/$(1)/clean ;
# build... delegate to generic target
$(1): $(1)/install
$(1)/: $(1)/install
fast/$(1): fast/$(1)/install
endef

else  # mono build

ALL_TARGETS += $(foreach p,$(PROJECTS),$(p) $(p)/ $(p)/test)

define PROJECT_settings
$(1)/%:
	@$(DIR)/build-env --require-kerberos-distcc $(DIR)/make.sh mono $(1)/$$*
$(1) $(1)/:
	@$(DIR)/build-env --require-kerberos-distcc $(DIR)/make.sh mono $(1)/all
$(1)/test: MAKEFLAGS += MONO_ARGS=-L\ '^$(1)$$$$$$$$'
$(1)/test:
	@$(DIR)/build-env --check-kerberos $(DIR)/make.sh mono test
endef

endif

$(foreach proj,$(PROJECTS),$(eval $(call PROJECT_settings,$(proj))))

ifneq ($(MONO_BUILD),1)

define PROJECT_settings_clean
# exception for purge: always do fast/Project/purge
$(1)/purge: fast/$(1)/purge ;
fast/$(1)/purge:
	$(RM) -r $(BUILD_PATH)/$(1)/build.$(BINARY_TAG) $(BUILD_PATH)/$(1)/InstallArea/$(BINARY_TAG)
	find $(1) "(" -name "InstallArea" -prune -o -name "*.pyc" ")" -a -type f -exec $(RM) -v \{} \;
# clean
$(1)-clean: $(patsubst %,%-clean,$($(1)_INV_DEPS))
	$$(MAKE) fast/$(1)-clean
fast/$(1)-clean:
	@test -d $(BUILD_PATH)/$(1)/build.$(BINARY_TAG) && $$(MAKE) $(1)/clean || true
	$(RM) -r $(BUILD_PATH)/$(1)/InstallArea/$(BINARY_TAG)
endef
$(foreach proj,$(ALL_PROJECTS),$(eval $(call PROJECT_settings_clean,$(proj))))
ALL_TARGETS += $(foreach p,$(ALL_PROJECTS),$(p)-clean fast/$(p)-clean)

endif

# stack.code-workspace is always remade by setup-make.py, so this is just
# to avoid the message "Nothing to be done for `stack.code-workspace'"
stack.code-workspace: ;@# noop
# same for special targets
update report: ;@# noop

.PHONY: $(ALL_TARGETS) stack.code-workspace

# ignore -j flag and run serially
.NOTPARALLEL:

# debugging
# print-%  : ; @echo $* = $($*)
