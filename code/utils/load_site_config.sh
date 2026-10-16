#!/bin/bash

# Export configuration variables from site_config.yaml

# directory of this script (./code/utils)
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# First, check that the file exists:
if [ ! -f "$REPO_ROOT/site_config.yaml" ]; then
    echo "site_config.yaml not found!"
    exit 1
fi

# Export variables
eval $(python3 - <<END
import yaml
with open("$REPO_ROOT/site_config.yaml") as f:
    config = yaml.safe_load(f)
for key, value in config.items():
    print(f'export {key}="{value}"')
END
)

