import os
import sys
from Future import lhcb_upgrade as slot

with open(sys.argv[1], 'w') as makefile:
    names = set(p.name for p in slot.projects)
    for p in slot.projects:
        deps = names.intersection(p.dependencies())
        makefile.write('{0}: {1}\n'
                       .format(p.name, ' '.join(deps)))
