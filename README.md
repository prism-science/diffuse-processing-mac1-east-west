# Diffuse scattering data processing for apo Mac1 (SARS-CoV-2 nsp3 macrodomain)

This repository contains the [DIALS](https://dials.github.io) and [mdx2](https://github.com/prism-science/mdx2) processing scripts used to produce the diffuse scattering maps of apo Mac1 reported in:

Zielinski K, Meisburger S, Lu K, Bassim V, Holton J, Fraser JS, Ando N. (2026). Iterating diffuse scattering protocols in parallel leads to reproducible, high-quality data from Mac1. The Stacks. [DOI: 10.82153/hrpy-t681](https://doi.org/10.82153/hrpy-t681)

It is a [DataLad](https://www.datalad.org) dataset intended for reproducibility and reuse. The processed results (mdx2 maps, MTZ files, reports, and logs) are tracked with git-annex and stored on the Open Storage Network (OSN). The source (raw) diffraction images are provided as DataLad subdatasets under `inputs/raw/`. Both are publicly available through anonymous access, with no credentials required.

## Contents

```
code/scripts/        processing scripts (one per dataset; see below)
code/utils/          helpers for site configuration and for collecting results
envs/                conda environment (DIALS, mdx2)
inputs/raw/          raw diffraction data (DataLad subdatasets)
inputs/reference/    reference model (PDB 7KQO) used to resolve indexing ambiguity
results/             processed outputs, organized as <collection>/<dataset>/<sample>/{dials,mdx2}
site_config.yaml.dist  template for local settings
```

The datasets fall into two collections:

- `mac1-east-west`: four high-quality datasets (two from ALS, two from CHESS) that are the basis of the maps described in the article.
- `mac1-suboptimal`: lower-quality datasets, affected by small crystal size, poor humidity control, or excessive dose. They are analyzed in the article to identify the experimental factors that matter for high-quality diffuse maps.

## Scripts

Each script fetches its own raw data (`datalad get`), processes every crystal with DIALS and mdx2, and merges the crystals. For datasets with several crystals, `mac1_merge` is the combined dataset, and `mac1_merge_lo` and `mac1_merge_hi` are merges of the first and second halves of each rotation range. All merges also report random half-set statistics.

| Script | Collection / dataset | Crystals | Description |
|---|---|---|---|
| `run_als_20251015.sh` | `mac1-east-west/als_20251015` | `mac1_10`, `mac1_12`, `mac1_13` | DIALS + mdx2 processing and merging |
| `run_als_20251125.sh` | `mac1-east-west/als_20251125` | `mac1_2`, `mac1_4` | DIALS + mdx2 processing and merging |
| `run_chess_20250924.sh` | `mac1-east-west/chess_20250924` | `mac1_2`, `mac1_3`, `mac1_5` | DIALS + mdx2 processing and merging (Eiger data) |
| `run_chess_20251105.sh` | `mac1-east-west/chess_20251105` | `mac1_4`, `mac1_5` | DIALS + mdx2 processing and merging (Eiger data, 7200 images per crystal) |
| `run_chess_20250924_combos.sh` | `mac1-east-west/chess_20250924/combos` | all 1-, 2-, and 3-crystal combinations | Re-merges the outputs of `run_chess_20250924.sh` to assess the effect of the number of crystals |
| `run_als_20250701_humidity.sh` | `mac1-suboptimal/als_20250701` | `xtal3`, `xtal7`, `xtal9`, `xtal10` | DIALS processing and merging only; crystals with different humidity control |
| `run_als_20251015_high_dose.sh` | `mac1-suboptimal/als_20251015` | `mac1_7` | DIALS + mdx2 processing of a single crystal exposed to a high dose |
| `run_als_20260423_small_xtals.sh` | `mac1-suboptimal/als_20260423` | `mac1_4`, `mac1_6`, `mac1_7` | DIALS + mdx2 processing and merging of small crystals |

### Processing outline

1. **DIALS** (per crystal): import, find spots, index (space group P4<sub>3</sub>), refine, integrate, scale, and reindex against the reference model `inputs/reference/7KQO.pdb`. Crystals are then scaled together to produce Bragg-intensity MTZ files and reports.
2. **mdx2** (per crystal): bin the background images, then import, find and mask Bragg peaks, integrate the diffuse scattering on a 3D grid, and apply corrections using the DIALS geometry and the binned background.
3. **mdx2** (per dataset): scale the crystals, merge with outlier rejection into random half-sets, and generate reports (map statistics, visualization, scaling model).

## Using the results

Install [DataLad](https://handbook.datalad.org/en/latest/intro/installation.html) (which includes git-annex), then clone this repository and fetch only what you need:

```bash
datalad clone https://github.com/prism-science/diffuse-processing-mac1-east-west.git
cd diffuse-processing-mac1-east-west

# list the available files (no data are downloaded yet)
ls results/mac1-east-west/chess_20250924/mac1_merge/mdx2

# download specific results
datalad get results/mac1-east-west/chess_20250924/mac1_merge/mdx2

# or everything under a collection
datalad get -J4 results/mac1-east-west
```

Files are retrieved anonymously from OSN. Plain git-annex works as well (`git annex get <path>`). To also access the raw images, install the subdatasets (metadata only) and then fetch the datasets of interest:

```bash
datalad get -n -r .
datalad get inputs/raw/mac1-east-west/chess_20250924
```

Merged maps are NeXus files (`merged.nxs`) that can be read with [mdx2](https://github.com/prism-science/mdx2) or `nexusformat`. Each `merged.nxs` is accompanied by HTML reports and logs.

## Reproducing the calculations

**Requirements.** Linux, [conda/mamba](https://github.com/conda-forge/miniforge), and sufficient disk space, memory, and cores. Processing `chess_20251105` (7200 Eiger images per crystal) requires nearly 350 Gb of RAM (with current mdx2 version, RAM usage will be addressed in a future release). The raw images are downloaded to a subdirecetory of the repo, so it should be installed on a large volume. Processed files are similarly large: set `project_directory` (below) to a large volume.

1. **Create the environment** and add DataLad, if not already installed globally (the scripts use datalad to fetch inputs):

   ```bash
   mamba env create -n dials_mdx2 -f envs/dials_mdx2.yaml
   mamba activate dials_mdx2
   mamba install -c conda-forge datalad
   ```

2. **Clone the repository** and install the subdatasets as described above (`datalad get -n -r .`).

3. **Configure the site.** Copy `site_config.yaml.dist` to `site_config.yaml` and set all three values:

   ```yaml
   project_directory: /absolute/path/to/workdir   # DIALS and mdx2 outputs are written here
   mdx2_nproc: 24                                 # parallel jobs for mdx2
   dials_nproc: 24                                # parallel processes for DIALS
   ```

4. **Run a script** from the repository root, ideally in a persistent session such as `screen`:

   ```bash
   bash -x code/scripts/run_chess_20250924.sh
   ```

   Outputs are written to `<project_directory>/<collection>/<dataset>/`. `run_chess_20250924_combos.sh` must be run after `run_chess_20250924.sh`.

   Scripts sometimes fail during the datalad get step if files are corrupted during transfer. Rerun the script to fetch the missing files and proceed.

5. **Compare with the archived results** in `results/`. To store new outputs in the repository (copying logs, reports, MTZ files, and `merged`, `corrected`, and `scales` NeXus files), use:

   ```bash
   datalad run -m 'update results after running code/scripts/run_chess_20250924.sh' \
       -o 'results/mac1-east-west/chess_20250924/**' --explicit \
       'bash code/utils/update_results.sh mac1-east-west/chess_20250924'
   ```

## License

MIT; see [LICENSE](LICENSE).
