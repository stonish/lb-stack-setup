import os
import sys
from Future import lhcb_upgrade as slot

with open(sys.argv[1], 'w') as makefile:
    makefile.write('PROJECTS = {0}\n'
                   .format(' '.join(p.name for p in slot.projects)))
    for p in slot.projects:
        makefile.write('{0}_DIR = {1}'.format(p.name, p.baseDir))
