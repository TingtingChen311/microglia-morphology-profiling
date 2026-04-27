#!/bin/bash
#SBATCH --job-name=cp_preproc
#SBATCH --partition=regularshort
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=04:00:00
#SBATCH --output=preprocess_%j.out
#
# SLURM submission script for Step 1 (PIL preprocessing).
#
# Site-specific values (module names, partition, paths) are set for the
# Hábrók cluster at the University of Groningen. Adapt for other clusters.
#
# Usage:
#     # Edit the IN_DIR and OUT_DIR variables below, then:
#     sbatch slurm/preprocess.sbatch

set -euo pipefail

# --- User-configurable paths ---------------------------------------------
# Override on the command line by exporting before sbatch, e.g.
#   export IN_DIR=/path/to/raw OUT_DIR=/path/to/filtered
#   sbatch slurm/preprocess.sbatch
: "${IN_DIR:=$HOME/morphology_analysis/exp1/raw}"
: "${OUT_DIR:=$HOME/morphology_analysis/exp1/Filtered_Images}"

# --- Site-specific environment (Hábrók) ----------------------------------
module load Python/3.12.3-GCCcore-13.3.0
source ~/py312/bin/activate

# --- Job ------------------------------------------------------------------
echo "==== JOB START ===="
date
echo "Host:     $(hostname)"
echo "IN_DIR=$IN_DIR"
echo "OUT_DIR=$OUT_DIR"

# Locate the project root (this script lives in <repo>/segmentation/slurm/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

python "$PROJECT_DIR/segmentation/1_preprocess.py" \
    --input  "$IN_DIR" \
    --output "$OUT_DIR"

echo "==== JOB END ===="
date
