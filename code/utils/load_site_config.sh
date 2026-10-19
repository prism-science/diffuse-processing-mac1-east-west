#!/bin/bash

# Export configuration variables from site_config.yaml

# directory of this script (./code/utils)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." &> /dev/null && pwd)"

# First, check that the file exists:
if [ ! -f "$REPO_ROOT/site_config.yaml" ]; then
    echo "site_config.yaml not found!"
    exit 1
fi

# Validate and export configuration variables from site_config.yaml
CONFIG_EXPORTS=$(python3 - "$REPO_ROOT/site_config.yaml" <<'END'
import os
import shlex
import sys

import yaml

path = sys.argv[1]
known = {"project_directory", "mdx2_nproc", "dials_nproc"}

with open(path) as f:
    config = yaml.safe_load(f)

if not isinstance(config, dict):
    sys.exit(f"ERROR: {path} must be a mapping of keys to values")

for key in config:
    if key not in known:
        print(f"WARNING: ignoring unknown key '{key}' in {path}", file=sys.stderr)

errors = []

project_directory = config.get("project_directory")
if project_directory is None:
    errors.append("missing required key 'project_directory'")
elif not (isinstance(project_directory, str) and os.path.isabs(project_directory)):
    errors.append(f"'project_directory' must be an absolute path, got {project_directory!r}")

mdx2_nproc = config.get("mdx2_nproc")
if mdx2_nproc is None:
    errors.append("missing required key 'mdx2_nproc'")
elif isinstance(mdx2_nproc, bool) or not isinstance(mdx2_nproc, int) or mdx2_nproc == 0:
    errors.append(f"'mdx2_nproc' must be a nonzero integer, got {mdx2_nproc!r}")

dials_nproc = config.get("dials_nproc")
if dials_nproc is None:
    errors.append("missing required key 'dials_nproc'")
elif isinstance(dials_nproc, bool) or not isinstance(dials_nproc, int) or dials_nproc < 1:
    errors.append(f"'dials_nproc' must be a positive integer, got {dials_nproc!r}")

if errors:
    for msg in errors:
        print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)

print(f"export project_directory={shlex.quote(project_directory)}")
print(f"export mdx2_nproc={mdx2_nproc}")
print(f"export dials_nproc={dials_nproc}")
END
) || exit 1

eval "$CONFIG_EXPORTS"
