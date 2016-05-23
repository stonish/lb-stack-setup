
.definitions.mk:
	python gen_make_definitions.py $@
-include .definitions.mk

.checkout.stamp: checkout.py Future.py .definitions.mk
	$(RM) -r $(PROJECTS_DIRS)
	python checkout.py
