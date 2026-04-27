#!/usr/bin/env bash
#
# Step 2: Cellpose-SAM segmentation of preprocessed iMGL images.
#
# Wraps the Cellpose CLI with the frozen parameters used in Chen et al.
# Requires `cellpose` (≥ 4.0) and a CUDA-capable GPU (CPU also supported but slow).
#
# Usage:
#     bash 2_segment.sh <input_dir> <output_dir>
#
# Where <input_dir> contains *_filt.tif files produced by 1_preprocess.py.

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <input_dir> <output_dir>" >&2
    echo "  <input_dir>  : directory containing *_filt.tif images" >&2
    echo "  <output_dir> : directory for Cellpose-SAM masks" >&2
    exit 1
fi

IN_DIR="$1"
OUT_DIR="$2"

if [[ ! -d "$IN_DIR" ]]; then
    echo "ERROR: input directory does not exist: $IN_DIR" >&2
    exit 2
fi

N=$(find "$IN_DIR" -maxdepth 1 -type f -iname "*_filt.tif" | wc -l)
if [[ "$N" -eq 0 ]]; then
    echo "ERROR: no *_filt.tif files found in $IN_DIR" >&2
    echo "       Did you run 1_preprocess.py first?" >&2
    exit 3
fi
echo "Input: $N filtered images in $IN_DIR"

mkdir -p "$OUT_DIR"
echo "Output: $OUT_DIR"

# Verify GPU availability (warn if absent; do not fail)
python - <<'PY'
import torch
if torch.cuda.is_available():
    print(f"GPU detected: {torch.cuda.get_device_name(0)}")
    print(f"PyTorch:     {torch.__version__}")
    print(f"CUDA build:  {torch.version.cuda}")
else:
    print("WARNING: CUDA is not available. Cellpose-SAM will run on CPU "
          "and may be ~10x slower.")
PY

echo
echo "==== Running Cellpose-SAM ===="
date

# Frozen parameters (see params.yml; do not modify when reproducing the published analysis)
python -u -m cellpose \
    --dir "$IN_DIR" \
    --pretrained_model cpsam \
    --use_gpu \
    --batch_size 1 \
    --diameter 25 \
    --flow_threshold 1.1 \
    --cellprob_threshold -3 \
    --norm_percentile 1 99 \
    --niter 600 \
    --save_tif \
    --no_npy \
    --verbose \
    --savedir "$OUT_DIR"

echo
echo "==== Segmentation complete ===="
date
echo "Masks written to: $OUT_DIR"
