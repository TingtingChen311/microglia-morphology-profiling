# ============================================================
# run_all.R
# Reproduce all figures in Chen et al. from CellProfiler output.
#
# Prerequisites:
#   - data/Exp{1,2,3}_SegmentedCells.csv
#   - data/Exp{1,2,3}_Metadata.csv
#   (download from Zenodo; see data/README.md)
#
# Usage:
#   From the project root, run:
#     Rscript run_all.R
#   Or open microglia-morphology-profiling.Rproj in RStudio and source this file.
#
# Expected runtime: ~20–40 min on a workstation with 16 GB RAM.
# Outputs: PNG and PDF figures under output/
# ============================================================

# Load `here` for path management (works regardless of working directory)
if (!requireNamespace("here", quietly = TRUE)) {
  install.packages("here")
}
library(here)
here::i_am("run_all.R")

# Sanity-check that data files are present
required_files <- c(
  here("data", "Exp1_SegmentedCells.csv"),
  here("data", "Exp1_Metadata.csv"),
  here("data", "Exp2_SegmentedCells.csv"),
  here("data", "Exp2_Metadata.csv"),
  here("data", "Exp3_SegmentedCells.csv"),
  here("data", "Exp3_Metadata.csv")
)
missing <- required_files[!file.exists(required_files)]
if (length(missing) > 0) {
  stop("Missing input files:\n  ", paste(missing, collapse = "\n  "),
       "\n\nSee data/README.md for download instructions.")
}

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)

# ---------- Step 1: Load and preprocess (creates cp_all, meta_all, dat_image, etc.) ----------
message("\n========== Step 1/3: Loading and preprocessing ==========")
source(here("R", "load_and_preprocess.R"))

# ---------- Step 2: Generate frozen state anchors ----------
# This step is deterministic (seed = 123). It overwrites R/state_anchors.rds
# only if you want to regenerate them. Skip if already present.
message("\n========== Step 2/3: Defining morphology state anchors ==========")
if (!file.exists(here("R", "state_anchors.rds"))) {
  source(here("R", "define_state_anchors.R"))
} else {
  message("R/state_anchors.rds already exists; skipping anchor regeneration.")
  message("Delete the file and rerun if you want to regenerate anchors.")
}

# ---------- Step 3: Knit each figure ----------
message("\n========== Step 3/3: Knitting figures ==========")
if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  install.packages("rmarkdown")
}

figure_rmds <- c(
  "Figure1D_reproducibility.Rmd",
  "Figure2_timecourse.Rmd",
  "Figure3.Rmd",
  "Figure4_cytokines.Rmd",
  "Figure5.Rmd",
  "Figure6.Rmd",
  "Figure_S.Rmd"
)

for (rmd in figure_rmds) {
  rmd_path <- here("analyses", rmd)
  if (!file.exists(rmd_path)) {
    warning("Skipping missing file: ", rmd)
    next
  }
  message("\n--- Knitting ", rmd, " ---")
  rmarkdown::render(
    input       = rmd_path,
    output_dir  = here("output"),
    quiet       = FALSE,
    envir       = new.env()  # isolate each figure's environment
  )
}

message("\n========== run_all.R complete ==========")
message("Figures and tables are in: ", here("output"))
