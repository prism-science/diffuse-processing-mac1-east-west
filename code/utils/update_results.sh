#!/bin/bash

# usage:
#   ./update_results.sh <subdirectory>

subdirectory="${1:-}"

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# source the configuration variables
source "$SCRIPT_DIR/load_site_config.sh"

: "${project_directory:?project_directory not set in site_config.yaml}"

SRC="${project_directory}/${subdirectory}/"
DEST="${REPO_ROOT}/results/${subdirectory}/"

mkdir -p "$DEST"

rsync -avm \
   --include='*.log' \
   --include='*.html' \
   --include='*.ipynb' \
   --include='*.json' \
   --include='*.mtz' \
   --include='merged*.nxs' \
   --include='corrected*.nxs' \
   --include='scales*.nxs' \
   --include='*/' \
   --exclude='*' \
   "$SRC" "$DEST"
