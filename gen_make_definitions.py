import os
import sys
from Future import lhcb_upgrade as slot

with open(sys.argv[1], 'w') as makefile:
    makefile.write('PROJECTS = {0}\n'
                   .format(' '.join(p.name for p in slot.projects)))
    makefile.write('PROJECTS_UPCASE = {0}\n'
                   .format(' '.join(p.name.upper() for p in slot.projects)))
    makefile.write('PROJECTS_DIRS = {0}\n'
                   .format(' '.join(p.baseDir for p in slot.projects)))

    for p in slot.projects:
        makefile.write('{0}_DIR = {1}\n'
                       '{0}: checkout\n'
                       '\t$(MAKE) -C {1} install\n'
                       .format(p.name, p.baseDir))
