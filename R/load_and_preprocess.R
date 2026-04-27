# ============================================================
# load_and_preprocess.R
# Step 1: Load & merge three independent experiments,
#         unify treatment naming, sanity-check against Well row.
# Memory-optimized: only loads needed feature columns from CP.
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
})

# Defensive: ensure dplyr wins if MASS was loaded in the session
select <- dplyr::select
filter <- dplyr::filter
# ---------- Configuration ----------
DATA_DIR <- "data"

# Only these columns are read from SegmentedCells.csv (saves ~95% RAM)
NEEDED_CP_COLS <- c(
  "ImageNumber",
  "ObjectNumber",
  "AreaShape_Area",
  "AreaShape_Perimeter",
  "AreaShape_Solidity",
  "AreaShape_Extent",
  "AreaShape_Eccentricity",
  "AreaShape_FormFactor",
  "Neighbors_NumberOfNeighbors_Adjacent",
  "Neighbors_PercentTouching_Adjacent"
)

# ---------- Treatment naming map ----------
treatment_map <- tribble(
  ~Treatment_raw,    ~Stimulus,  ~IL34,
  "Vehicle",         "Vehicle",  "neg",
  "Vehicle_IL34",    "Vehicle",  "pos",
  "IL1b",            "IL1beta",  "neg",
  "IL1b_IL34",       "IL1beta",  "pos",
  "TNFa",            "TNFa",     "neg",
  "TNFa_IL34",       "TNFa",     "pos",
  "IL6",             "IL6",      "neg",
  "IL6_IL34",        "IL6",      "pos",
  "IFNr",            "IFNg",     "neg",
  "IFNr_IL34",       "IFNg",     "pos",
  "LPS",             "LPS",      "neg",
  "LPS_IL34",        "LPS",      "pos",
  "LPS+IFNr",        "LPS+IFNg", "neg",
  "LPS+IFNr_IL34",   "LPS+IFNg", "pos",
  "IL34neg_Vehicle", "Vehicle",  "neg",
  "IL34pos_Vehicle", "Vehicle",  "pos",
  "IL34neg_IL1beta", "IL1beta",  "neg",
  "IL34pos_IL1beta", "IL1beta",  "pos",
  "IL34neg_TNFa",    "TNFa",     "neg",
  "IL34pos_TNFa",    "TNFa",     "pos"
)

# ---------- Non-cell filter ----------
filter_non_cells <- function(cp, exp_label,
                             area_min     = 50,      # absolute lower bound (px^2); adjust to your magnification
                             area_max     = NULL,    # NULL = no upper bound; use MAD-based filter instead
                             solidity_min = 0.70,
                             mad_k        = 5) {     # MAD multiplier
  n0 <- nrow(cp)
  
  # MAD outlier rule on log(Area) (log space is more symmetric for Area)
  la <- log(cp$AreaShape_Area)
  med <- median(la, na.rm = TRUE)
  mad_v <- mad(la, na.rm = TRUE)
  la_lo <- med - mad_k * mad_v
  la_hi <- med + mad_k * mad_v
  
  keep <- cp$AreaShape_Area >= area_min &
    la >= la_lo & la <= la_hi &
    cp$AreaShape_Solidity >= solidity_min
  if (!is.null(area_max)) keep <- keep & cp$AreaShape_Area <= area_max
  
  # Track removals per rule (for diagnostics)
  n_small    <- sum(cp$AreaShape_Area < area_min, na.rm = TRUE)
  n_mad_lo   <- sum(la < la_lo, na.rm = TRUE)
  n_mad_hi   <- sum(la > la_hi, na.rm = TRUE)
  n_lowsolid <- sum(cp$AreaShape_Solidity < solidity_min, na.rm = TRUE)
  
  out <- cp[keep & !is.na(keep), ]
  message(sprintf(
    "%s: non-cell filter kept %d / %d (%.1f%%) | small=%d, MAD_lo=%d, MAD_hi=%d, lowSolid=%d",
    exp_label, nrow(out), n0, 100 * nrow(out) / n0,
    n_small, n_mad_lo, n_mad_hi, n_lowsolid))
  out
}

# ---------- Load one experiment (memory-optimized) ----------
load_experiment <- function(exp_label) {
  cp_path   <- file.path(DATA_DIR, paste0(exp_label, "_SegmentedCells.csv"))
  meta_path <- file.path(DATA_DIR, paste0(exp_label, "_Metadata.csv"))
  
  message("\n--- Loading ", exp_label, " ---")
  
  # Metadata is small, load fully
  meta_raw <- read_csv(meta_path, guess_max = 2e5, show_col_types = FALSE) %>%
    rename_with(~ gsub("\ufeff", "", .x))
  
  meta <- meta_raw %>%
    mutate(
      Treatment = str_trim(as.character(Treatment)),
      WellRow   = str_extract(Well, "^[A-Z]"),
      Experiment = exp_label
    ) %>%
    filter(Treatment != "" & !is.na(Treatment)) %>%
    left_join(treatment_map, by = c("Treatment" = "Treatment_raw"))
  
  # Sanity check 1: every treatment got mapped
  unmapped <- meta %>% filter(is.na(Stimulus)) %>% pull(Treatment) %>% unique()
  if (length(unmapped) > 0) {
    stop(exp_label, ": unmapped Treatment values: ", paste(unmapped, collapse = ", "))
  }
  
  # Sanity check 2: Well row matches IL34 label
  mismatch <- meta %>%
    mutate(expected = case_when(
      WellRow %in% c("A","B","C","D") ~ "neg",
      WellRow %in% c("E","F","G")     ~ "pos",
      TRUE                            ~ NA_character_
    )) %>%
    filter(!is.na(expected) & expected != IL34)
  
  if (nrow(mismatch) > 0) {
    warning(exp_label, ": ", nrow(mismatch),
            " rows where Treatment label disagrees with Well row")
    print(mismatch %>% select(Filename, Well, Treatment, IL34, expected) %>% head())
  } else {
    message(exp_label, ": Well-row sanity check PASSED (",
            nrow(meta), " images)")
  }
  
  meta <- meta %>% mutate(ImageNumber = paste0(exp_label, "_", ImageNumber))
  
  # ---- CP file: peek at columns first, then load only needed ones ----
  cp_header <- read_csv(cp_path, n_max = 0, show_col_types = FALSE) %>%
    rename_with(~ gsub("\ufeff", "", .x))
  total_cols <- ncol(cp_header)
  available <- intersect(NEEDED_CP_COLS, names(cp_header))
  missing   <- setdiff(NEEDED_CP_COLS, names(cp_header))
  
  message(exp_label, ": CP has ", total_cols, " total columns, loading ",
          length(available), " of them")
  if (length(missing) > 0) {
    warning(exp_label, ": missing CP columns: ", paste(missing, collapse = ", "))
  }
  
  cp <- read_csv(cp_path,
                 col_select = all_of(available),
                 guess_max = 2e5,
                 show_col_types = FALSE,
                 progress = FALSE) %>%
    rename_with(~ gsub("\ufeff", "", .x)) %>%
    mutate(ImageNumber = paste0(exp_label, "_", ImageNumber)) %>%
    filter(ImageNumber %in% meta$ImageNumber)
  
  cp <- filter_non_cells(cp, exp_label)
  message(exp_label, ": loaded ", nrow(cp), " cells")
  
  # Force garbage collection to release memory between experiments
  gc(verbose = FALSE)
  
  list(cp = cp, meta = meta)
}


# ---------- Load all three ----------
message("\n========== Loading three experiments ==========")
e1 <- load_experiment("Exp1")
e2 <- load_experiment("Exp2")
e3 <- load_experiment("Exp3")

cp_all <- bind_rows(e1$cp, e2$cp, e3$cp)
meta_all <- bind_rows(e1$meta, e2$meta, e3$meta) %>%
  mutate(
    Experiment = factor(Experiment, levels = c("Exp1","Exp2","Exp3")),
    Stimulus   = factor(Stimulus, levels = c(
      "Vehicle","LPS","IFNg","LPS+IFNg","IL1beta","IL6","TNFa")),
    IL34       = factor(IL34, levels = c("neg","pos"))
  )


# Free per-experiment objects
rm(e1, e2, e3); gc(verbose = FALSE)

dup <- meta_all$ImageNumber[duplicated(meta_all$ImageNumber)]
if (length(dup) > 0) stop("Duplicated ImageNumbers: ", paste(head(dup, 5), collapse=", "))

# ---------- Diagnostic tables ----------
message("\n========== Diagnostic tables ==========")

message("\n--- Stimulus × Experiment (IL34pos) ---")
print(meta_all %>% filter(IL34 == "pos") %>%
        count(Stimulus, Experiment) %>%
        pivot_wider(names_from = Experiment, values_from = n))

message("\n--- Stimulus × Experiment (IL34neg) ---")
print(meta_all %>% filter(IL34 == "neg") %>%
        count(Stimulus, Experiment) %>%
        pivot_wider(names_from = Experiment, values_from = n))

message("\n--- Experiment × Time_hr ---")
print(meta_all %>% count(Experiment, Time_hr) %>%
        pivot_wider(names_from = Time_hr, values_from = n))

message("\n--- Total images per experiment ---")
print(meta_all %>% count(Experiment))

message("\n========== Load complete ==========")
message("Total images: ", nrow(meta_all))
message("Total cells:  ", nrow(cp_all))
message("Approx memory: ",
        round(as.numeric(object.size(cp_all)) / 1e9, 2), " GB (cp_all)")
# ============================================================
# Step 2: Feature set, image-level aggregation, centering, global PCA
# ============================================================

MORPH_FEATURES <- c(
  "AreaShape_Area", "AreaShape_Perimeter", "AreaShape_Solidity",
  "AreaShape_Extent", "AreaShape_Eccentricity", "AreaShape_FormFactor",
  "Neighbors_NumberOfNeighbors_Adjacent",
  "Neighbors_PercentTouching_Adjacent"
)
LOG_COLS <- c(
  "AreaShape_Area", "AreaShape_Perimeter",
  "Neighbors_NumberOfNeighbors_Adjacent",
  "Neighbors_PercentTouching_Adjacent"
)


# ---- Image-level median profile ----
dat_image_raw <- cp_all %>%
  filter(complete.cases(across(all_of(MORPH_FEATURES)))) %>%
  inner_join(
    meta_all %>% select(ImageNumber, Experiment, Stimulus, IL34, Time_hr, Well),
    by = "ImageNumber"
  ) %>%
  group_by(ImageNumber, Experiment, Stimulus, IL34, Time_hr, Well) %>%
  summarise(across(all_of(MORPH_FEATURES), \(x) median(x, na.rm = TRUE)),
            n_cells = n(), .groups = "drop")
dat_image_raw <- dat_image_raw %>% filter(n_cells >= 20)
message("Images kept after n_cells >= 20 filter: ", nrow(dat_image_raw))
message("Image-level profiles: ", nrow(dat_image_raw))

# ---- Low-variance filter (no correlation filter, per earlier decision) ----
feature_var <- sapply(dat_image_raw[MORPH_FEATURES], var, na.rm = TRUE)
final_features <- names(feature_var)[feature_var > 1e-10 & !is.na(feature_var)]
message("Features kept after low-variance filter: ", length(final_features),
        " / ", length(MORPH_FEATURES))

# ---- Log-transform, then per-experiment centering ----
# experiment offset = mean of each (Stimulus x Time x IL34) cell, then unweighted mean
# within experiment. This prevents centering baseline from being biased by uneven
# numbers of wells/images per condition.
exp_offset <- dat_image_raw %>%
  mutate(across(all_of(intersect(LOG_COLS, final_features)), log1p)) %>%
  filter(Stimulus == "Vehicle") %>%                                        # only Vehicle defines baseline
  group_by(Experiment, Time_hr, IL34) %>%                                  # do NOT group by Stimulus
  summarise(across(all_of(final_features), \(x) mean(x, na.rm = TRUE)),
            .groups = "drop") %>%
  group_by(Experiment) %>%
  summarise(across(all_of(final_features), \(x) mean(x, na.rm = TRUE)),
            .groups = "drop")

dat_image <- dat_image_raw %>%
  mutate(across(all_of(intersect(LOG_COLS, final_features)), log1p)) %>%
  left_join(exp_offset, by = "Experiment", suffix = c("", ".exp")) %>%
  mutate(across(all_of(final_features),
                ~ .x - get(paste0(cur_column(), ".exp")))) %>%
  select(-ends_with(".exp"))

# ---- Global image-level PCA ----
X_global <- as.matrix(dat_image[, final_features])
pca_model <- prcomp(X_global, center = TRUE, scale. = TRUE)

var_exp <- pca_model$sdev^2 / sum(pca_model$sdev^2)
message("PC1-PC5 variance explained: ",
        paste0(round(100 * var_exp[1:5], 1), "%", collapse = ", "))

scores_all <- as.data.frame(pca_model$x) %>%
  bind_cols(dat_image %>% select(ImageNumber, Experiment, Stimulus,
                                 IL34, Time_hr, Well, n_cells))
# ---- Sanity check: verify per-experiment centering removes batch offset ----
# Expected: mean_area_centered ~ 0 for each experiment if centering worked
# ---- Sanity check: Vehicle should be ~0, activated stimuli should shift ----
stim_check <- dat_image %>%
  filter(IL34 == "pos", Time_hr %in% c(4, 8, 24)) %>%
  group_by(Stimulus) %>%
  summarise(
    n_images           = n(),
    mean_area_centered = mean(AreaShape_Area, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(mean_area_centered)

message("\n--- Sanity check: centered Area per stimulus (IL34pos, t=4/8/24) ---")
message("Vehicle should be ~ 0; activated stimuli should show positive shift")
print(stim_check)


message("\n========== Step 2 complete ==========")
message("Objects available for figure Rmds:")
message("  - cp_all, meta_all       (single-cell + metadata)")
message("  - dat_image              (image-level, centered)")
message("  - final_features         (feature names used)")
message("  - pca_model, scores_all  (global image-level PCA)")

rm(dat_image_raw, X_global, feature_var, var_exp)
gc(verbose = FALSE)
# ============================================================
# Step 3: Single-cell preprocessing helper (used by Figure 3 & 5)
# ============================================================

#' Prepare a downsampled single-cell matrix for a subset of conditions.
#'
#' @param cp Single-cell data frame (cp_all).
#' @param meta Metadata data frame (meta_all).
#' @param stimuli Character vector of stimuli to include (e.g. c("Vehicle","LPS+IFNg")).
#' @param il34 "pos" or "neg".
#' @param target_time Numeric time point (e.g. 4).
#' @param cells_per_group Target cells per (Stimulus × Experiment). Default 1667.
#' @param seed Random seed for reproducibility.
#'
#' @return A list with:
#'   sc_raw: full single-cell table (not downsampled) with metadata joined
#'   sc_ds:  downsampled table (stratified by Stimulus × Experiment)
#'   features: character vector of final_features actually used
prepare_singlecell <- function(cp, meta,
                               stimuli,
                               il34 = "pos",
                               target_time,
                               cells_per_group = 1667,
                               seed = 123) {
  stopifnot(exists("final_features"))
  stopifnot("AreaShape_Area" %in% names(cp))   # defensive check
  
  log_cols_actual <- intersect(LOG_COLS, final_features)
  
  # 1. Filter to subset, preserving original Area before any transformation
  sc_raw <- cp %>%
    inner_join(
      meta %>% select(ImageNumber, Experiment, Stimulus, IL34, Time_hr, Well),
      by = "ImageNumber"
    ) %>%
    filter(
      Stimulus %in% stimuli,
      IL34 == !!il34,
      Time_hr == target_time
    ) %>%
    filter(complete.cases(across(all_of(final_features)))) %>%
    mutate(
      Stimulus           = factor(Stimulus, levels = stimuli),
      Experiment         = factor(Experiment, levels = c("Exp1","Exp2","Exp3"))
      )
  
  stopifnot(nrow(sc_raw) > 0)   # ensure data remains after filtering
  
  # 2. Stratified downsampling
  # Compute per-group cell counts; smallest group sets the upper bound
  actual_n_per_group <- sc_raw %>%
    group_by(Stimulus, Experiment) %>%
    summarise(n = n(), .groups = "drop")
  
  min_available <- min(actual_n_per_group$n)
  n_sample <- min(cells_per_group, min_available)
  
  if (n_sample < cells_per_group) {
    warning(sprintf("Requested %d cells/group but smallest group has %d. Using %d.",
                    cells_per_group, min_available, n_sample))
  }
  
  set.seed(seed)
  sc_ds <- sc_raw %>%
    group_by(Stimulus, Experiment) %>%
    slice_sample(n = n_sample) %>%
    ungroup()
  
  # --- Step 3: Calculate Balanced Baseline ---
  # We extract the mean from the balanced downsampled set (sc_ds) 
  # to ensure the baseline is not biased by treatments with more cells.
  stopifnot(exists("exp_offset"))   
  
  apply_experiment_centering <- function(df) {
    df %>%
      mutate(across(all_of(log_cols_actual), log1p)) %>%
      left_join(exp_offset, by = "Experiment", suffix = c("", ".exp")) %>%
      mutate(across(all_of(final_features),
                    ~ .x - get(paste0(cur_column(), ".exp")))) %>%
      select(-ends_with(".exp"))
  }
  
  sc_ds  <- apply_experiment_centering(sc_ds)
  sc_raw <- apply_experiment_centering(sc_raw)
  return(list(sc_raw = sc_raw, sc_ds = sc_ds, features = final_features))}
  
#' Derive interpretable morphology axes from a single-cell data frame.
#' @param df   data frame with AreaShape_Area/FormFactor/Eccentricity (centered)
#' @param scaling optional tibble with columns axis/mean/sd. If provided,
#'        applies fixed z-scoring (consistency across figures). If NULL,
#'        scales from own data (only used when defining anchors).
add_morphology_axes <- function(df, scaling = NULL) {
  df <- df %>%
    mutate(
      SizeProxy      = AreaShape_Area,
      RoundnessProxy = AreaShape_FormFactor,
      Elongation     = AreaShape_Eccentricity
    )
  
  if (is.null(scaling)) {
    df %>% mutate(
      z_size  = as.numeric(scale(SizeProxy)),
      z_round = as.numeric(scale(RoundnessProxy)),
      z_elong = as.numeric(scale(Elongation))
    )
  } else {
    get_p <- function(ax) scaling[scaling$axis == ax, ]
    df %>% mutate(
      z_elong = (Elongation     - get_p("z_elong")$mean) / get_p("z_elong")$sd,
      z_size  = (SizeProxy      - get_p("z_size")$mean)  / get_p("z_size")$sd,
      z_round = (RoundnessProxy - get_p("z_round")$mean) / get_p("z_round")$sd
    )
  }
}

#' Classify single cells by nearest-anchor assignment.
#' Not to be confused with match_clusters_to_anchors(), which does 1:1
#' Hungarian matching between sets of centroids.
assign_cells_to_nearest_anchor <- function(df, anchors,
                                           feature_cols = c("z_elong","z_size","z_round")) {
  anchor_mat <- as.matrix(anchors[, feature_cols])
  cell_mat   <- as.matrix(df[, feature_cols])
  
  d2 <- sapply(seq_len(nrow(anchor_mat)), function(j) {
    rowSums(sweep(cell_mat, 2, anchor_mat[j, ], "-")^2)
  })
  nearest <- max.col(-d2, ties.method = "first")
  anchors$state_name[nearest]
}
#' Match new k-means clusters to reference anchors by centroid distance.
#'
#' @param new_centroids Data frame with cluster_id + anchor feature columns.
#' @param anchors Data frame of reference anchors (saved to R/state_anchors.rds).
#' @return Named character: cluster_id -> state_name
match_clusters_to_anchors <- function(new_centroids, anchors,
                                      feature_cols = c("z_elong","z_size","z_round")) {
  combined <- bind_rows(
    anchors %>% mutate(.source = "anchor"),
    new_centroids %>% mutate(.source = "new")
  )
  for (fc in feature_cols) {
    m <- mean(combined[[fc]], na.rm = TRUE)
    s <- sd(combined[[fc]], na.rm = TRUE)
    combined[[fc]] <- (combined[[fc]] - m) / s
  }
  
  anc <- combined %>% filter(.source == "anchor")
  new <- combined %>% filter(.source == "new")
  
  # Cost matrix
  cost <- matrix(NA, nrow = nrow(new), ncol = nrow(anc))
  for (i in seq_len(nrow(new))) {
    for (j in seq_len(nrow(anc))) {
      cost[i, j] <- sqrt(sum(
        (as.numeric(new[i, feature_cols]) - as.numeric(anc[j, feature_cols]))^2
      ))
    }
  }
  
  # Hungarian algorithm for globally optimal 1:1 assignment
  if (requireNamespace("clue", quietly = TRUE)) {
    assignment <- clue::solve_LSAP(cost)
    result <- setNames(anc$state_name[assignment], new$cluster_id)
  } else {
    # Fallback to greedy if clue not installed
    warning("Package 'clue' not available; using greedy matching")
    result <- character(nrow(new))
    for (k in seq_len(nrow(new))) {
      idx <- which(cost == min(cost, na.rm = TRUE), arr.ind = TRUE)[1, ]
      result[idx[1]] <- anc$state_name[idx[2]]
      cost[idx[1], ] <- NA; cost[, idx[2]] <- NA
    }
    names(result) <- new$cluster_id
  }
  result
}
  
message("Step 3: single-cell helpers loaded")
message("  - prepare_singlecell()")
message("  - add_morphology_axes()")
message("  - match_clusters_to_anchors()")
# In R/load_and_preprocess.R, at the end:

# ============================================================
# Pre-specified time points for single-cell analyses
# ============================================================
# Selected a priori, independent of this dataset. Based on commonly-used
# time windows in published microglial / myeloid cytokine-response studies:
#
#   - 4 h:  early-response phase (onset of morphological remodeling;
#           NF-κB / early cytokine-induced transcriptional peak)
#   - 24 h: late / sustained response phase (standard endpoint for
#           functional assays and late transcriptional programs)
#
# References: Sabogal-Guáqueta et al. (Nat Commun 2023; ref [27]);
#             Koskuvi et al. (Mol Psychiatry 2024; ref [28]).
#
# Image-level time-course data for all 13 acquired time points are shown in
# Figures 2 and 4. Single-cell state fraction trajectories across all time
# points are provided as Supplementary Figure SX (FigureS_timecourse.Rmd).
SC_TIMEPOINTS <- c(4, 24)

message("Single-cell analysis time points: ",
        paste(SC_TIMEPOINTS, "h", collapse = ", "))

transparent_theme <- ggplot2::theme(
  plot.background       = ggplot2::element_rect(fill = "transparent", colour = NA),
  panel.background      = ggplot2::element_rect(fill = "transparent", colour = NA),
  legend.background     = ggplot2::element_rect(fill = "transparent", colour = NA),
  legend.box.background = ggplot2::element_rect(fill = "transparent", colour = NA),
  legend.key            = ggplot2::element_rect(fill = "transparent", colour = NA)
)
message("  - transparent_theme (for transparent backgrounds in ggsave)")



         
    

