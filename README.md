# Single-cell, label-free morphology profiling of iPSC-derived microglia

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.XXXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Code and analysis pipeline accompanying:

> **Chen T, Li X, Dolga AM.** Single-cell, label-free morphology profiling of iPSCs-derived microglia reveals dynamic state transitions. *Journal Name* (Year). DOI: [link]

This repository contains the complete pipeline for label-free, time-resolved morphological profiling of human iPSC-derived microglia (iMGLs), combining live-cell imaging, Cellpose-SAM segmentation, and CellProfiler-based feature extraction with downstream R analyses.

---

## Overview

We developed a label-free pipeline that combines (i) live-cell phase-contrast imaging, (ii) deep learning–based segmentation with Cellpose-SAM, and (iii) quantitative single-cell feature extraction with CellProfiler, to track iMGL morphology at single-cell resolution over 24 h. Six pro-inflammatory conditions (LPS, IFNγ, IL-1β, IL-6, TNFα, and LPS+IFNγ co-stimulation) were profiled across three independent differentiation runs, and four reproducible morphological states (Elongated, Spread, Ramified, Small_Round) were defined and frozen for downstream analysis.

---

## Repository structure

```
.
├── README.md
├── LICENSE
├── CITATION.cff
├── environment.yml              # Python env (Cellpose-SAM)
├── renv.lock                    # R dependency lockfile
├── cellprofiler/
│   └── pipeline.cppipe          # Feature extraction pipeline (CellProfiler v4.2.8)
├── segmentation/
│   ├── run_cellpose_sam.py      # Batch segmentation script
│   └── params.yml               # Frozen segmentation parameters
├── R/
│   ├── state_anchors.rds        # Frozen 4-state anchor centroids + scaling
│   ├── 00_preprocessing.R       # Object filtering, log-transform, vehicle centering
│   ├── 01_image_level_pca.R     # Fig. 1, Fig. 2, Fig. 4A–B
│   ├── 02_singlecell_umap.R     # UMAP embedding (Fig. 3, Fig. 5)
│   ├── 03_state_assignment.R    # Nearest-anchor classification
│   ├── 04_texture_complexity.R  # PC1 of Haralick features (Fig. 3E–F, Fig. 5F)
│   ├── 05_ros_analysis.R        # Fig. 6 (CellROX)
│   └── figures/
│       ├── fig1.R … fig6.R
│       ├── figS1.R, figS2.R
│       └── tables.R             # Table S1, Table S2
└── data/
    └── README.md                # Pointer to Zenodo / BioImage Archive
```

---

## System requirements

| Component | Version | Notes |
|-----------|---------|-------|
| OS | Linux / macOS / Windows | Tested on Ubuntu 22.04 |
| Python | ≥ 3.10 | For Cellpose-SAM |
| GPU | CUDA-capable | Recommended for segmentation |
| R | 4.4.2 | Tested version |
| CellProfiler | 4.2.8 | Exact version used |

**R packages:** `tidyverse`, `uwot`, `patchwork`, `ggpubr`, `ggforce`, `ggrepel`, `cluster`, `MASS`, `scales`, `lme4`, `lmerTest`, `emmeans`

**Python packages:** `cellpose-sam`, `numpy`, `tifffile`, `pyyaml` (see `environment.yml`)

---

## Installation

Clone the repository and set up both environments:

```bash
git clone https://github.com/<username>/microglia-morphology-profiling.git
cd microglia-morphology-profiling

# Python environment for Cellpose-SAM
conda env create -f environment.yml
conda activate cpsam

# R environment
R -e 'install.packages("renv"); renv::restore()'
```

Typical install time on a standard desktop: ~15 min.

---

## Data availability

Raw and processed data are archived separately due to size:

| Resource | Location | DOI |
|----------|----------|-----|
| Raw phase-contrast images (Incucyte S3) | BioImage Archive / Zenodo | `10.xxxx/xxxxx` |
| CellProfiler per-cell measurement CSVs | Zenodo | `10.5281/zenodo.XXXXXXX` |
| Frozen state anchors (`state_anchors.rds`) | This repo (`R/`) | — |

After downloading, place CSV outputs under `data/cellprofiler_output/` following the structure documented in `data/README.md`.

---

## Reproducing the figures

All stochastic steps use **`set.seed(123)`**. Run the analysis end-to-end:

```bash
# 1. Segment images (GPU recommended)
python segmentation/run_cellpose_sam.py \
    --input data/raw_images \
    --output data/masks \
    --params segmentation/params.yml

# 2. Extract features with CellProfiler (headless mode)
cellprofiler -c -r \
    -p cellprofiler/pipeline.cppipe \
    -i data/masks \
    -o data/cellprofiler_output

# 3. Run R analysis (in order)
Rscript R/00_preprocessing.R
Rscript R/01_image_level_pca.R
Rscript R/02_singlecell_umap.R
Rscript R/03_state_assignment.R
Rscript R/04_texture_complexity.R
Rscript R/05_ros_analysis.R

# 4. Generate figures
Rscript R/figures/fig1.R
# … fig2.R through fig6.R, figS1.R, figS2.R
Rscript R/figures/tables.R
```

Expected runtime on a workstation (NVIDIA RTX 3090, 32 GB RAM): segmentation ~3 h for the full dataset; R analyses ~20 min total.

---

## Key parameters (frozen)

For full reproducibility, the following parameters are **frozen** across all analyses:

**Cellpose-SAM segmentation**
- Pretrained model: `cpsam` (no fine-tuning)
- Input: single-channel grayscale (`channels = [0, 0]`)
- Object diameter: 25 px
- `flow_threshold = 1.1`, `cellprob_threshold = −3`
- Normalization: 1st–99th percentile
- 600 iterations, batch size 1

**Object filtering (per experiment)**
- Area ≥ 50 px²
- log(area) within ±5 MAD of per-experiment median
- Solidity ≥ 0.70

**Single-cell sampling**
- 1,667 cells per (Stimulus × Experiment), stratified random sampling, seed 123

**UMAP**
- PCs explaining ≥ 95% cumulative variance
- `n_neighbors = 50`, `min_dist = 0.5`, metric `"euclidean"`, seed 123

**State assignment**
- 4 states: Elongated, Spread, Ramified, Small_Round
- K-means (k = 4, nstart = 25, iter.max = 50, seed 123) on z_size, z_round, z_elong
- Trained once on Vehicle + LPS+IFNγ pooled across all 13 time points and 3 experiments
- Saved to `R/state_anchors.rds` and reused for all downstream figures via nearest-anchor assignment

---

## Citation

If you use this code, please cite both the paper and the archived release:

```bibtex
@article{Chen2025iMGL,
  title   = {Single-cell, label-free morphology profiling of iPSCs-derived microglia reveals dynamic state transitions},
  author  = {Chen, Tingting and Li, Xiaopeng and Dolga, Amalia M.},
  journal = {Journal Name},
  year    = {2025},
  doi     = {10.xxxx/xxxxx}
}

@software{Chen2025iMGL_code,
  author    = {Chen, Tingting},
  title     = {microglia-morphology-profiling: code release v1.0.0},
  year      = {2025},
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.XXXXXXX}
}
```

---

## License

Code is released under the MIT License (see `LICENSE`). The accompanying CellProfiler pipeline and analysis scripts are free to reuse with attribution.

---

## Contact

- **Tingting Chen** — t.chen@rug.nl
- **Amalia M. Dolga** — a.m.dolga@rug.nl

Department of Molecular Pharmacology, Groningen Research Institute of Pharmacy, University of Groningen, the Netherlands

---

## Acknowledgments

We thank Prof. Bart Eggen (UMCG) for providing the human iPSC line. This work was supported by Alzheimer Nederland (WE.03-2024-18), Parkinson Fonds (1899), and ZonMw Open Competitie (09120012110068).
