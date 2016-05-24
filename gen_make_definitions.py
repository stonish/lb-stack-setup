import os
import sys
from Future import lhcb_upgrade as slot

with open(sys.argv[1], 'w') as makefile:
    makefile.write('PROJECTS = {0}\n'
                   .format(' '.join(p.name for p in slot.activeProjects)))
    makefile.write('PROJECTS_UPCASE = {0}\n'
                   .format(' '.join(p.name.upper()
                                    for p in slot.activeProjects)))
    makefile.write('PROJECTS_DIRS = {0}\n'
                   .format(' '.join(p.baseDir for p in slot.activeProjects)))

    for p in slot.projects:
        makefile.write('{0}_DIR = {1}\n'
                       '{0}: checkout\n'
                       '\t$(MAKE) -C {1} install\n'
                       '{0}-clean:\n'
                       '\ttest -d {1}/build.$(CMTCONFIG) && \\\n'
                       '\t  $(MAKE) -C {1} clean ; \\\n'
                       '\t  $(RM) -r {1}/InstallArea/$(CMTCONFIG)\n'
                       .format(p.name, p.baseDir))
