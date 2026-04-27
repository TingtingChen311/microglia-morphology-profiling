# Single-cell, label-free morphology profiling of iPSC-derived microglia

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.XXXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Code and analysis pipeline accompanying:

> **Chen T, Li X, Dolga AM.** Single-cell, label-free morphology profiling of iPSCs-derived microglia reveals dynamic state transitions. *Journal Name* (Year). DOI: [link]

This repository contains the complete pipeline for label-free, time-resolved morphological profiling of human iPSC-derived microglia (iMGLs), combining live-cell phase-contrast imaging, image preprocessing in Python, deep-learning segmentation with Cellpose-SAM, CellProfiler-based feature extraction, and downstream R analyses.

---

## Overview

We developed a label-free pipeline that combines (i) live-cell phase-contrast imaging, (ii) image preprocessing and deep-learning segmentation with Cellpose-SAM, and (iii) quantitative single-cell feature extraction with CellProfiler, to track iMGL morphology at single-cell resolution over 24 h. Six pro-inflammatory conditions (LPS, IFNγ, IL-1β, IL-6, TNFα, and LPS+IFNγ co-stimulation) were profiled across three independent differentiation runs, and four reproducible morphological states (Elongated, Spread, Ramified, Small_Round) were defined and frozen for downstream analysis.

---

## Repository structure

```
.
├── README.md
├── LICENSE                              # MIT License
├── CITATION.cff                         # Citation metadata
├── .gitignore
├── environment.yml                      # Python env for preprocessing + Cellpose-SAM
├── microglia-morphology-profiling.Rproj # RStudio project file
├── run_all.R                            # Main R entry point (renders all figure Rmds)
├── R/
│   ├── load_and_preprocess.R            # Load CellProfiler CSVs, filter, log-transform, vehicle-center
│   ├── define_state_anchors.R           # Define 4-state anchors via k-means (training-only script)
│   └── state_anchors.rds                # Frozen anchor centroids + scaling (used by all figures)
├── analyses/
│   ├── Figure1D_reproducibility.Rmd     # Figure 1D (segmentation reproducibility)
│   ├── Figure2_timecourse.Rmd           # Figure 2 (image-level time course)
│   ├── Figure3.Rmd                      # Figure 3 (single-cell UMAP, state assignment, texture)
│   ├── Figure4_cytokines.Rmd            # Figure 4 (cytokine panel)
│   ├── Figure5.Rmd                      # Figure 5 (24 h treatment comparison)
│   ├── Figure6.Rmd                      # Figure 6 (CellROX / ROS analysis)
│   └── Figure_S.Rmd                     # Supplementary figures and tables
├── cellprofiler/
│   └── pipeline.cppipe                  # Feature-extraction pipeline (CellProfiler v4.2.8)
├── segmentation/
│   ├── README.md                        # Segmentation step-by-step instructions
│   ├── 1_preprocess.py                  # Image preprocessing (PIL: UnsharpMask + GaussianBlur)
│   ├── 2_segment.sh                     # Cellpose-SAM batch wrapper
│   ├── params.yml                       # Frozen segmentation parameters
│   └── slurm/
│       ├── preprocess.sbatch            # SLURM job script for preprocessing
│       └── segment.sbatch               # SLURM job script for segmentation (GPU)
└── data/
    └── README.md                        # Pointer to Zenodo / BioImage Archive
```

---

## System requirements

This pipeline uses two compute environments:

| Stage | Environment | Notes |
|-------|-------------|-------|
| Image preprocessing + Cellpose-SAM segmentation | Linux HPC with NVIDIA GPU + SLURM | Tested on Hábrók cluster (Univ. of Groningen) with CUDA 12.1 |
| CellProfiler feature extraction | Linux / macOS | Tested on macOS 14 |
| R downstream analysis | Linux / macOS | Tested on macOS 14 |

| Component | Version | Notes |
|-----------|---------|-------|
| Python | 3.12.3 | |
| Pillow (PIL) | 11.3.0 | Image preprocessing |
| Cellpose-SAM | 4.0.6 | Segmentation |
| PyTorch | 2.5.1 | with CUDA 12.1 |
| CellProfiler | 4.2.8 | Feature extraction |
| R | 4.4.2 | Downstream analysis |

**R packages:** `tidyverse`, `here`, `uwot`, `patchwork`, `ggpubr`, `ggforce`, `ggrepel`, `cluster`, `MASS`, `scales`, `lme4`, `lmerTest`, `emmeans`, `rmarkdown`, `knitr`

**Python packages:** `cellpose`, `torch`, `pillow`, `numpy`, `tifffile`, `pyyaml` (see `environment.yml`)

---

## Installation

Clone the repository and set up the Python environment:

```bash
git clone https://github.com/TingtingChen311/microglia-morphology-profiling.git
cd microglia-morphology-profiling

# Python environment for preprocessing + Cellpose-SAM
conda env create -f environment.yml
conda activate cpsam
```

For the R analysis, open `microglia-morphology-profiling.Rproj` in RStudio and install the packages listed under **System requirements**:

```r
install.packages(c(
  "tidyverse", "here", "uwot", "patchwork", "ggpubr", "ggforce",
  "ggrepel", "cluster", "MASS", "scales", "lme4", "lmerTest",
  "emmeans", "rmarkdown", "knitr"
))
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

After downloading the CellProfiler outputs, place them under `data/cellprofiler_output/` following the structure documented in `data/README.md`.

---

## Reproducing the figures

All stochastic steps use **`set.seed(123)`**. The pipeline runs in three stages:

### Stage 1 — Image preprocessing and segmentation (HPC)

On a Linux GPU node, after activating the `cpsam` conda environment:

```bash
# Preprocess raw phase-contrast TIFFs (PIL: UnsharpMask + GaussianBlur)
python segmentation/1_preprocess.py \
    --input  data/raw_images \
    --output data/filtered_images

# Run Cellpose-SAM segmentation
bash segmentation/2_segment.sh \
    --input  data/filtered_images \
    --output data/masks \
    --params segmentation/params.yml
```

If you use SLURM, equivalent job scripts are provided:

```bash
sbatch segmentation/slurm/preprocess.sbatch
sbatch segmentation/slurm/segment.sbatch
```

### Stage 2 — Feature extraction (CellProfiler, headless)

```bash
cellprofiler -c -r \
    -p cellprofiler/pipeline.cppipe \
    -i data/masks \
    -o data/cellprofiler_output
```

### Stage 3 — R analysis and figure generation

From the project root, open `microglia-morphology-profiling.Rproj` in RStudio and run:

```r
source("run_all.R")
```

This loads and preprocesses the CellProfiler output, applies the frozen state anchors from `R/state_anchors.rds`, and renders all figure R Markdown files in `analyses/`. Individual figures can also be rendered separately, e.g.:

```r
rmarkdown::render("analyses/Figure3.Rmd")
```

Expected runtime on a workstation (NVIDIA RTX 3090, 32 GB RAM): segmentation ~3 h for the full dataset; R analyses ~20 min total.

---

## Key parameters (frozen)

For full reproducibility, the following parameters are **frozen** across all analyses:

**Image preprocessing (Pillow 11.3.0)**
- For multi-page TIFFs, only the first frame is retained
- 8-bit grayscale conversion
- Unsharp mask: `radius = 10 px`, `percent = 100`, `threshold = 0`
- Gaussian blur: `radius = 0.4 px`

**Cellpose-SAM segmentation (v4.0.6, PyTorch 2.5.1 + CUDA 12.1)**
- Pretrained model: `cpsam` (no fine-tuning)
- Input: single-channel grayscale (`channels = [0, 0]`)
- Object diameter: 25 px
- `flow_threshold = 1.1`, `cellprob_threshold = -3`
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
