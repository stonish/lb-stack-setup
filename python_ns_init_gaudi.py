import os
if os.path.exists(fname):
    with open(fname) as f:
        code = compile(f.read(), fname, 'exec')
        exec (code)
