#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." &>/dev/null && pwd)"

# load site configuration variables:
# project_directory, dials_nproc, mdx2_nproc
source "$REPO_ROOT/code/utils/load_site_config.sh"

RAW_DATA="$REPO_ROOT/inputs/raw/"
SUBDIR="mac1-suboptimal/als_20251015/"
PROJECT_ROOT="$project_directory/$SUBDIR"
REFERENCE_PDB="inputs/reference/7KQO.pdb"

# fetch the reference dataset if needed
( cd "$REPO_ROOT" && datalad get "$REFERENCE_PDB" )

# fetch the raw data if needed
( cd "$RAW_DATA" && datalad get "$SUBDIR" )

sample="mac1_7"
image="mac1_7_3_00001.cbf"
range="1,3600"
(
    mkdir -p "$PROJECT_ROOT/$sample/dials"
    cd "$PROJECT_ROOT/$sample/dials"
    cp "$REPO_ROOT/$REFERENCE_PDB" reference.pdb
    dials.import "$RAW_DATA/$SUBDIR/$sample/crystal/$image" image_range=$range
    dials.find_spots imported.expt nproc=$dials_nproc
    dials.index imported.expt strong.refl space_group=P43
    dials.refine indexed.expt indexed.refl
    dials.integrate refined.expt refined.refl nproc=$dials_nproc
    dials.scale integrated.expt integrated.refl d_min=1.1
    dials.reindex scaled.expt scaled.refl reference.file=reference.pdb
    dials.report reindexed.expt reindexed.refl
    dials.merge reindexed.expt reindexed.refl
)

image="mac1_7_bg_1_2_00001.cbf"
range="1,360"
(
    mkdir -p "$PROJECT_ROOT/$sample/mdx2/bg"
    cd "$PROJECT_ROOT/$sample/mdx2/bg"
    dials.import "$RAW_DATA/$SUBDIR/$sample/background/$image" image_range=$range
    mdx2.import_data imported.expt --nproc $mdx2_nproc
    mdx2.bin_image_series data.nxs 5 10 10 --valid_range 0 100 --nproc $mdx2_nproc
)


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

split_corrected_nxs() {
    python <<-EOF
from mdx2.io import loadobj, saveobj
from mdx2.data import HKLTable
hkl_table = loadobj("corrected.nxs", "hkl_table")
phi_range = hkl_table.phi.max() - hkl_table.phi.min()
phi_mid = 0.5*hkl_table.phi.min() + 0.5*hkl_table.phi.max()
print(f"Splitting corrected.nxs at phi = {phi_mid} (total range: {phi_range})")
df = hkl_table.to_frame()
hkl_table_lo = HKLTable.from_frame(df[df["phi"] < phi_mid])
hkl_table_hi = HKLTable.from_frame(df[df["phi"] >= phi_mid])
hkl_table_lo.ndiv = hkl_table.ndiv
hkl_table_hi.ndiv = hkl_table.ndiv
saveobj(hkl_table_lo, "corrected_lo.nxs", "hkl_table")
saveobj(hkl_table_hi, "corrected_hi.nxs", "hkl_table")
EOF
}


(
    mkdir -p "$PROJECT_ROOT/$sample/mdx2"
    cd "$PROJECT_ROOT/$sample/mdx2"
    mdx2.import_data ../dials/reindexed.expt --nproc $mdx2_nproc 
    mdx2.import_geometry ../dials/reindexed.expt
    mdx2.find_peaks geometry.nxs data.nxs --count_threshold 20 --nproc $mdx2_nproc
    mdx2.mask_peaks geometry.nxs data.nxs peaks.nxs --nproc $mdx2_nproc
    mdx2.integrate geometry.nxs data.nxs --mask mask.nxs --subdivide 2 2 4 --nproc $mdx2_nproc
    mdx2.correct geometry.nxs integrated.nxs --background bg/binned.nxs
    split_corrected_nxs
    mdx2.scale corrected.nxs --mca2020
    mdx2.merge corrected.nxs --scale scales.nxs --split randomHalf --outlier 5
    # add the crystal and symmetry objects to merged.nxs (from the first dataset)
    copy_crystal_and_symmetry_to_merged_nxs .
    mdx2.report --template map_statistics merged.nxs
    mdx2.report --template visualization merged.nxs
    mdx2.report --template scaling_model scales.nxs
)

for suffix in lo hi; do
    (
        merge_dir="$PROJECT_ROOT/mac1_merge_${suffix}/mdx2"
        mkdir -p "$merge_dir"
        cd "$merge_dir"

        mdx2.merge "../../$sample/mdx2/corrected_${suffix}.nxs" \
            --scale "../../$sample/mdx2/scales.nxs" \
            --split randomHalf --outlier 5

        # Add crystal and symmetry objects from the first sample.
        copy_crystal_and_symmetry_to_merged_nxs \
            "../../$sample/mdx2"

        mdx2.report --template map_statistics merged.nxs
        mdx2.report --template visualization merged.nxs
    )
done