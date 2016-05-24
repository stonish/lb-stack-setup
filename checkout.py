import os
import logging
from Future import lhcb_upgrade
from subprocess import call

logging.basicConfig(level=logging.DEBUG if os.environ.get('VERBOSE')
                    else logging.INFO)

# update the clones (not done by the checkout method of the slot)
for p in lhcb_upgrade.projects:
    if os.path.exists(os.path.join(p.baseDir, '.git')):
        call(['git', 'fetch', 'origin'], cwd=p.baseDir)
lhcb_upgrade.checkout()
lhcb_upgrade.patch()
