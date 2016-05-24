import os
import sys
from Future import lhcb_upgrade as slot

with open(sys.argv[1], 'w') as makefile:
    # known projects
    names = set(p.name for p in slot.activeProjects)
    # dependency lines
    for p in slot.activeProjects:
        deps = names.intersection(p.dependencies())
        makefile.write('{0}: {1}\n'
                       .format(p.name, ' '.join(deps)))
        # clean up should be done in reverse dependency order
        for dep in deps:
            makefile.write('{0}-clean: {1}-clean\n'
                           .format(dep, p.name))
