#!/bin/bash

set -d

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# source the configuration variables
source "$SCRIPT_DIR/load_site_config.sh"

RESULTS="${SCRIPT_DIR}/../../results/"

rsync -avm \
   --include='*.log'\
   --include='*.html' \
   --include='*.ipynb' \
   --include='*.json' \
   --include='*.mtz' \
   --include='merged*.nxs' \
   --include='corrected*.nxs' \
   --include='scales*.nxs' \
   --include='*/' \
   --exclude='*' \
   "${project_directory}/" "$RESULTS"
