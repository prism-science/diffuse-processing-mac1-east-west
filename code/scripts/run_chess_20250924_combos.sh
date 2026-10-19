#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# load site configuration variables:
# project_directory, dials_nproc, mdx2_nproc
source "$REPO_ROOT/code/utils/load_site_config.sh"

RAW_DATA="$REPO_ROOT/inputs/raw/"
SUBDIR="mac1-east-west/chess_20250924/"
PROJECT_ROOT="$project_directory/$SUBDIR"

copy_crystal_and_symmetry_to_merged_nxs() {
    local source_dir=$1

    python - "$source_dir" <<'PY'
import sys
from mdx2.io import loadobj, saveobj

geometry_file = f"{sys.argv[1]}/geometry.nxs"
crystal = loadobj(geometry_file, "crystal")
symmetry = loadobj(geometry_file, "symmetry")
saveobj(crystal, "merged.nxs", "crystal", append=True)
saveobj(symmetry, "merged.nxs", "symmetry", append=True)
PY
}

# Compare maps with different numbers of crystals (from chess_20250924)
while read -r combo; do
    (
        IFS='+' read -ra samples <<< "$combo"
        corrected=()
        scales=()
        for sample in "${samples[@]}"; do
            corrected+=("../../../$sample/mdx2/corrected.nxs")
            scales+=("../../../$sample/mdx2/scales.nxs")
        done

        mkdir -p "$PROJECT_ROOT/combos/$combo/mdx2"
        cd "$PROJECT_ROOT/combos/$combo/mdx2"
        mdx2.merge "${corrected[@]}" --scale "${scales[@]}" --split randomHalf --outlier 5
        # add the crystal and symmetry objects to merged.nxs (from the first dataset)
        copy_crystal_and_symmetry_to_merged_nxs "../../../${samples[0]}/mdx2"
        mdx2.report --template map_statistics merged.nxs
        mdx2.report --template visualization merged.nxs
    )
done <<EOF
mac1_2
mac1_3
mac1_5
mac1_2+mac1_3
mac1_2+mac1_5
mac1_3+mac1_5
mac1_2+mac1_3+mac1_5
EOF