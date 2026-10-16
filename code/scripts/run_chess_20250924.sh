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
REFERENCE_PDB="inputs/reference/7KQO.pdb"

# fetch the reference dataset if needed
( cd "$REPO_ROOT" && datalad get "$REFERENCE_PDB" )

# fetch the raw data if needed
( cd "$RAW_DATA" && datalad get "$SUBDIR" )

samples=()

while read -r sample image range; do
    samples+=("$sample")
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
        (
            mkdir -p estimate_resolution && cd estimate_resolution
            dials.scale ../integrated.expt ../integrated.refl
            dials.estimate_resolution scaled.expt scaled.refl
        )
        (
            mkdir -p truncated && cd truncated
            dials.scale ../integrated.expt ../integrated.refl d_min=1.25 output.json=scaled_truncated.json
        )
    )
done <<EOF
mac1_2 mac1_3_50_master.h5 1,3600
mac1_3 mac1_3_54_master.h5 1,3600
mac1_5 mac1_5_61_master.h5 1,3600
EOF

# combine the datasets
(
    mkdir -p "$PROJECT_ROOT/mac1_merge/dials"
    cd "$PROJECT_ROOT/mac1_merge/dials"
    merge_inputs=()
    for sample in "${samples[@]}"; do
        merge_inputs+=(
            "../../$sample/dials/reindexed.expt"
            "../../$sample/dials/reindexed.refl"
            )
    done
    dials.scale "${merge_inputs[@]}" d_min=1.1
    dials.report scaled.expt scaled.refl
    dials.merge scaled.expt scaled.refl

    # also scale with truncation at 1.25 ang.
    mkdir -p truncated
    dials.scale "${merge_inputs[@]}" d_min=1.25 \
        output.experiments=truncated/scaled.expt \
        output.reflections=truncated/scaled.refl \
        output.log=truncated/dials.scale.log \
        output.html=truncated/dials.scale.html \
        output.json=truncated/scaled_truncated.json
)

# process the background images for mdx2
while read -r sample image range; do
    (
        mkdir -p "$PROJECT_ROOT/$sample/mdx2/bg"
        cd "$PROJECT_ROOT/$sample/mdx2/bg"
        dials.import "$RAW_DATA/$SUBDIR/$sample/background/$image" image_range=$range
        mdx2.import_data imported.expt --nproc $mdx2_nproc
        mdx2.bin_image_series data.nxs 5 20 20 --valid_range 0 100 --nproc $mdx2_nproc
    )
done <<EOF
mac1_2 mac1_2_bg_51_master.h5 1,360
mac1_3 mac1_3_bg_55_master.h5 1,360
mac1_5 mac1_5_bg_62_master.h5 1,360
EOF

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

# process the crystal images for all samples using mdx2
for sample in "${samples[@]}"; do
    (
        mkdir -p "$PROJECT_ROOT/$sample/mdx2"
        cd "$PROJECT_ROOT/$sample/mdx2"
        mdx2.import_data ../dials/reindexed.expt --nproc $mdx2_nproc 
        mdx2.import_geometry ../dials/reindexed.expt
        mdx2.find_peaks geometry.nxs data.nxs --count_threshold 20 --nproc $mdx2_nproc
        mdx2.mask_peaks geometry.nxs data.nxs peaks.nxs --nproc $mdx2_nproc
        mdx2.integrate geometry.nxs data.nxs --mask mask.nxs --subdivide 2 2 4 --nproc $mdx2_nproc
        mdx2.correct geometry.nxs integrated.nxs --background bg/binned.nxs
        split_corrected_nxs # create corrected_lo.nxs and corrected_hi.nxs
    )
done

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

(
    mkdir -p "$PROJECT_ROOT/mac1_merge/mdx2"
    cd "$PROJECT_ROOT/mac1_merge/mdx2"
    scale_inputs=()
    scale_outputs=()
    for sample in "${samples[@]}"; do
        scale_inputs+=("../../$sample/mdx2/corrected.nxs")
        scale_outputs+=("../../$sample/mdx2/scales.nxs")
    done
    mdx2.scale "${scale_inputs[@]}" --mca2020
    mdx2.merge "${scale_inputs[@]}" --scale "${scale_outputs[@]}" --split randomHalf --outlier 5
    # add the crystal and symmetry objects to merged.nxs (from the first dataset)
    copy_crystal_and_symmetry_to_merged_nxs "../../${samples[0]}/mdx2"
    mdx2.report --template map_statistics merged.nxs
    mdx2.report --template visualization merged.nxs
    mdx2.report --template scaling_model "${scale_outputs[@]}"
)


for suffix in lo hi; do
    (
        merge_dir="$PROJECT_ROOT/mac1_merge_${suffix}/mdx2"
        mkdir -p "$merge_dir"
        cd "$merge_dir"

        merge_inputs=()
        scale_inputs=()
        for sample in "${samples[@]}"; do
            merge_inputs+=("../../$sample/mdx2/corrected_${suffix}.nxs")
            scale_inputs+=("../../$sample/mdx2/scales.nxs")
        done

        mdx2.merge "${merge_inputs[@]}" \
            --scale "${scale_inputs[@]}" \
            --split randomHalf --outlier 5

        # Add crystal and symmetry objects from the first sample.
        copy_crystal_and_symmetry_to_merged_nxs \
            "../../${samples[0]}/mdx2"

        mdx2.report --template map_statistics merged.nxs
        mdx2.report --template visualization merged.nxs
    )
done