#!/bin/bash
#SBATCH --job-name=cp_mask_gpu
#SBATCH --partition=gpushort
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --gres=gpu:1
#SBATCH --mem=64G
#SBATCH --time=02:00:00
#SBATCH --output=cellpose_%j.out
#
# SLURM submission script for Step 2 (Cellpose-SAM segmentation).
#
# Site-specific values (module names, partition, paths) are set for the
# Hábrók cluster at the University of Groningen. Adapt for other clusters.
#
# Usage:
#     # Edit the IN_DIR and OUT_DIR variables below, then:
#     sbatch slurm/segment.sbatch
#
# Note: before first use on a new cluster, install a CUDA-enabled torch:
#     pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cu121 \
#         torch torchvision

set -euo pipefail

# --- User-configurable paths ---------------------------------------------
: "${IN_DIR:=$HOME/morphology_analysis/exp1/Filtered_Images}"
: "${OUT_DIR:=$HOME/morphology_analysis/exp1/masks}"

# --- Site-specific environment (Hábrók) ----------------------------------
module load Python/3.12.3-GCCcore-13.3.0
module load CUDA/12.1.1
source ~/py312/bin/activate

# Cache locations on $HOME (some clusters have small /tmp)
export XDG_CACHE_HOME="$HOME/.cache"
export TORCH_HOME="$HOME/.cache/torch"
export HF_HOME="$HOME/.cache/huggingface"
mkdir -p "$XDG_CACHE_HOME" "$TORCH_HOME" "$HF_HOME"

# --- Job ------------------------------------------------------------------
echo "==== JOB START ===="
date
echo "Host:    $(hostname)"
echo "IN_DIR=$IN_DIR"
echo "OUT_DIR=$OUT_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

bash "$PROJECT_DIR/segmentation/2_segment.sh" "$IN_DIR" "$OUT_DIR"

echo "==== JOB END ===="
date
