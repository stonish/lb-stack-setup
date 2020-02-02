#!/usr/bin/python
"""Write project configuration in a makefile."""
from __future__ import print_function
import os
import re
from config import read_config

config = read_config()


try:
    import pathlib

    def mkdir_p(path):
        pathlib.Path(path).mkdir(parents=True, exist_ok=True)
except ImportError:
    def mkdir_p(path):
        try:
            os.makedirs(path)
        except OSError as exc:
            import errno
            if exc.errno == errno.EEXIST and os.path.isdir(path):
                pass
            else:
                raise


def parse_src_spec(spec):
    """Return name, url and branch from "group/project[:branch]"."""
    m = re.match(
        r'^(?P<fullname>([^/:]+/)+(?P<name>[^:]+))(:(?P<branch>[^:]+))?$',
        spec)
    if not m:
        raise ValueError("malformed source spec '{}'".format(spec))
    g = m.groupdict()
    return (
        g['name'],
        '{}/{}.git'.format(config['gitBase'], g['fullname']),
        g["branch"] or config["defaultBranch"]
        )


# save the host environment where we're executed
output_path = config['outputPath']
mkdir_p(output_path)
with open(os.path.join(output_path, 'host.env'), 'w') as f:
    for name, value in sorted(os.environ.items()):
        print(name + "=" + value, file=f)

projects = []
urls = {}
branches = {}
for spec in config["projects"]:
    p, url, branch = parse_src_spec(spec)
    projects.append(p)
    urls[p] = url
    branches[p] = branch

# Second pass once all projects are known to determine dependencies
dependencies = {
    p: set(config['projectDeps'].get(p, "").split(" ")).intersection(projects)
    for p in projects
}
inv_dependencies = {
    d: set(p for p in projects if d in dependencies[p])
    for d in projects
}

data_packages = []
for spec in config["dataPackages"]:
    p, url, branch = parse_src_spec(spec)
    data_packages.append(p)
    urls[p] = url
    branches[p] = branch

config_path = os.path.join(output_path, "configuration.mk")
with open(config_path, "w") as f:
    print("CONTRIB_PATH := " + config["contribPath"], file=f)
    print("PROJECTS := " + " ".join(projects), file=f)
    for p in projects:
        print("{}_URL := {}".format(p, urls[p]), file=f)
        print("{}_BRANCH := {}".format(p, branches[p]), file=f)
        print("{}_DEPS := {}".format(p, ' '.join(dependencies[p])), file=f)
        print("{}_INV_DEPS := {}".format(p, ' '.join(inv_dependencies[p])),
              file=f)
    print("DATA_PACKAGES := " + " ".join(data_packages), file=f)
    for p in data_packages:
        print("{}_URL := {}".format(p, urls[p]), file=f)
        print("{}_BRANCH := {}".format(p, branches[p]), file=f)

print(config_path)
