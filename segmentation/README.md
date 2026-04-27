# Image preprocessing and segmentation

This directory contains the two-step image processing pipeline used in Chen et al.

## Pipeline overview

```
raw .tif  →  [Step 1: PIL preprocessing]  →  *_filt.tif  →  [Step 2: Cellpose-SAM]  →  *_masks.tif
```

| Step | Script | Input | Output |
|------|--------|-------|--------|
| 1. Preprocessing | `1_preprocess.py` | Raw phase-contrast TIFFs | Sharpened + lightly blurred TIFFs (`*_filt.tif`) |
| 2. Segmentation | `2_segment.sh` | `*_filt.tif` from Step 1 | Cellpose-SAM masks (`*_filt_cp_masks.tif`) |

All parameters are frozen and documented in `params.yml`.

---

## Quick start

### Requirements

- Python ≥ 3.10 (we used 3.12.3)
- Pillow ≥ 10.0
- Cellpose ≥ 4.0 (with the `cpsam` pretrained model)
- PyTorch with CUDA support (recommended for Step 2)

Install via the Conda environment file at the repository root:

```bash
conda env create -f ../environment.yml
conda activate microglia-morph
```

### Step 1 — Preprocessing

```bash
python 1_preprocess.py \
    --input  /path/to/raw_images \
    --output /path/to/filtered_images
```

Runtime: ~5 minutes for 1,000 images on a single CPU. Filenames are preserved with `_filt` suffix.

### Step 2 — Segmentation

```bash
bash 2_segment.sh \
    /path/to/filtered_images \
    /path/to/masks
```

Runtime: ~15 minutes for 1,000 images on an NVIDIA A100. CPU-only is supported but ~10× slower.

---

## Running on a SLURM HPC cluster

The `slurm/` subfolder contains the actual `.sbatch` files used to run this pipeline on the
[Hábrók](https://wiki.hpc.rug.nl/) cluster (University of Groningen). They are provided as
reference for HPC users; module names and partition names are site-specific and will need
to be adapted for other clusters.

```bash
# On the cluster head node
sbatch slurm/preprocess.sbatch
sbatch slurm/segment.sbatch    # submit after preprocess.sbatch finishes
```

---

## Frozen parameters

See `params.yml` for the complete parameter set. Key values:

**Preprocessing (PIL)**
- UnsharpMask: `radius=10, percent=100, threshold=0`
- GaussianBlur: `radius=0.4`
- First frame only (for multi-page TIFFs); converted to 8-bit grayscale

**Segmentation (Cellpose-SAM)**
- Pretrained model: `cpsam` (no fine-tuning)
- `diameter=25, flow_threshold=1.1, cellprob_threshold=-3`
- Normalization: 1st–99th percentile
- `niter=600, batch_size=1`
- Single-channel grayscale input
