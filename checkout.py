import os
import logging
from Future import lhcb_upgrade

logging.basicConfig(level=logging.DEBUG if os.environ.get('VERBOSE')
                    else logging.WARNING)

lhcb_upgrade.checkout()
lhcb_upgrade.patch()
