import os
import logging
from Future import lhcb_upgrade
from subprocess import call

logging.basicConfig(level=logging.DEBUG if os.environ.get('VERBOSE')
                    else logging.INFO)

# update the clones (not done by the checkout method of the slot)
projects = [p for p in lhcb_upgrade.projects if os.path.exists(os.path.join(p.baseDir, '.git'))]
for p in projects:
    call(['git', 'fetch', 'origin'], cwd=p.baseDir)
    call(['git', 'stash'], cwd=p.baseDir)
lhcb_upgrade.checkout()
for p in projects:
    call(['git', 'stash', 'pop'], cwd=p.baseDir)
lhcb_upgrade.patch()
