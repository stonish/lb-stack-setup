CONFIGFILE = Future.py

.definitions.mk: $(CONFIGFILE) gen_make_definitions.py
	python gen_make_definitions.py $@
-include .definitions.mk

.PHONY: all checkout build clean purge $(PROJECTS)

all: build
checkout: .checkout.stamp
build: checkout $(PROJECTS)
clean:
	for d in $(PROJECTS_DIRS) ; do (test -d  $$d && $(MAKE) -C $$d clean ; $(RM) -r $$d/InstallArea) ; done
purge:
	$(RM) -r $(PROJECTS_DIRS)

.checkout.stamp: checkout.py $(CONFIGFILE)
	python checkout.py
	touch .checkout.stamp
