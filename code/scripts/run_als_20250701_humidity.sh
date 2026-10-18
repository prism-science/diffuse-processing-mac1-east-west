#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# load site configuration variables:
# project_directory, dials_nproc, mdx2_nproc
source "$REPO_ROOT/code/utils/load_site_config.sh"

RAW_DATA="$REPO_ROOT/inputs/raw/"
SUBDIR="mac1-suboptimal/als_20250701/"
PROJECT_ROOT="$project_directory/$SUBDIR"
REFERENCE_PDB="inputs/reference/7KQO.pdb"

# fetch the reference dataset if needed
( cd "$REPO_ROOT" && datalad get "$REFERENCE_PDB" )

# fetch the raw data if needed
( cd "$RAW_DATA" && datalad get "$SUBDIR" )

while read -r sample image range; do
    (
        mkdir -p "$PROJECT_ROOT/$sample/dials"
        cd "$PROJECT_ROOT/$sample/dials"
        cp "$REPO_ROOT/$REFERENCE_PDB" reference.pdb
        dials.import "$RAW_DATA/$SUBDIR/$sample/crystal/$image" image_range=$range
        dials.find_spots imported.expt nproc=$dials_nproc
        dials.index imported.expt strong.refl space_group=P43
        dials.refine indexed.expt indexed.refl
        dials.integrate refined.expt refined.refl nproc=$dials_nproc
        dials.scale integrated.expt integrated.refl
        dials.reindex scaled.expt scaled.refl reference.file=reference.pdb
        dials.estimate_resolution scaled.expt scaled.refl
        d_min=$(awk '/^Resolution cc_half:/ {print $NF}' dials.estimate_resolution.log)
        dials.report reindexed.expt reindexed.refl
        dials.merge reindexed.expt reindexed.refl d_min=${d_min:-1.1}
    )
done <<EOF
xtal3 t1_1_00001.cbf 1,7200
xtal7 t1_1_00001.cbf 1,7200
xtal9 t1_1_00001.cbf 1,7200
xtal10 t1_1_00001.cbf 1,7200
EOF
