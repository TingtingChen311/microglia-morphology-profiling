# ============================================================
# define_state_anchors.R
# ------------------------------------------------------------
# ONE-SHOT SCRIPT: Defines canonical morphology state anchors.
#
# Run this script ONCE whenever the upstream preprocessing
# (load_and_preprocess.R) changes. It generates:
#   - R/state_anchors.rds          : frozen cluster-to-state map
#   - output/FigureS3_silhouette.rds : silhouette scores for k=2..8
#
# All downstream figures (Fig3, Fig5, Fig6, FigS3) READ these files.
# They never overwrite them.
#
# Decisions (see response letter):
#   - Training set: Vehicle + LPS+IFNg, IL34+, ALL timepoints pooled
#     Rationale: uses the two extreme conditions of the main contrast,
#     independent of any post-hoc timepoint selection.
#   - Data scope : sc_raw (full data, no downsampling).
#     Rationale: anchor positions should not depend on random seed.
#   - k          : 4, justified by biological interpretability
#     (Elongated / Spread / Ramified / Small_Round correspond to
#     canonical microglial morphologies). Silhouette analysis for
#     k=2..8 is saved as a sensitivity check (Supplementary Fig S3).
#   - Naming rule (unchanged from previous pipeline):
#       1. Cluster with highest z_elong -> "Elongated"
#       2. Of remaining, highest z_size  -> "Spread"
#       3. Of remaining, highest z_round -> "Small_Round"
#       4. The last one                  -> "Ramified"
# ============================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(cluster)
})

# ---- 0. Load preprocessing pipeline ----
if (!exists("cp_all") || !exists("meta_all") ||
    !exists("prepare_singlecell") || !exists("add_morphology_axes")) {
  source("R/load_and_preprocess.R")
}

ANCHOR_FILE    <- "R/state_anchors.rds"
SILHOUETTE_FILE <- "output/FigureS3_silhouette.rds"
dir.create("output", showWarnings = FALSE, recursive = TRUE)
dir.create("R",      showWarnings = FALSE, recursive = TRUE)

ANCHOR_K    <- 4
ANCHOR_SEED <- 123

# ============================================================
# 1. Assemble anchor training set
#    Vehicle + LPS+IFNg, IL34+, all timepoints pooled
# ============================================================
message("\n========== Building anchor training set ==========")

# We need sc_raw WITHOUT a single-timepoint filter.
# prepare_singlecell() only exposes one timepoint, so we bypass it
# here and replicate its centering logic on the pooled set.

log_cols_actual <- intersect(LOG_COLS, final_features)

anchor_raw <- cp_all %>%
  inner_join(
    meta_all %>% select(ImageNumber, Experiment, Stimulus, IL34, Time_hr, Well),
    by = "ImageNumber"
  ) %>%
  filter(
    Stimulus %in% c("Vehicle", "LPS+IFNg"),
    IL34 == "pos"
  ) %>%
  filter(complete.cases(across(all_of(final_features)))) %>%
  mutate(
    Stimulus   = factor(Stimulus,   levels = c("Vehicle", "LPS+IFNg")),
    Experiment = factor(Experiment, levels = c("Exp1", "Exp2", "Exp3"))
  )

stopifnot(nrow(anchor_raw) > 0)
message(sprintf("Anchor training set: %d cells across %d images",
                nrow(anchor_raw),
                length(unique(anchor_raw$ImageNumber))))
message("Breakdown (Stimulus x Experiment):")
print(table(anchor_raw$Stimulus, anchor_raw$Experiment))

# Apply the SAME per-experiment centering used by image-level data
stopifnot(exists("exp_offset"))
anchor_centered <- anchor_raw %>%
  mutate(across(all_of(log_cols_actual), log1p)) %>%
  left_join(exp_offset, by = "Experiment", suffix = c("", ".exp")) %>%
  mutate(across(all_of(final_features),
                ~ .x - get(paste0(cur_column(), ".exp")))) %>%
  select(-ends_with(".exp"))

# Derive morphology axes (z_elong / z_size / z_round)
anchor_with_axes <- anchor_centered %>% add_morphology_axes()

state_axes <- c("z_elong", "z_size", "z_round")
km_rows  <- complete.cases(anchor_with_axes[, state_axes])
km_input <- anchor_with_axes[km_rows, state_axes] %>% as.matrix()

message(sprintf("\nK-means input: %d cells x %d features",
                nrow(km_input), ncol(km_input)))

# Report pairwise correlations of the 3 axes (transparency for reviewer 4.1)
message("\nCorrelation of axes in training set:")
print(round(cor(km_input), 3))

# ============================================================
# 2. K-means with k = ANCHOR_K, used as canonical anchors
# ============================================================
message(sprintf("\n========== K-means with k=%d, nstart=25 ==========", ANCHOR_K))
message("(nstart=25 gives stable local optima at this scale)")

set.seed(ANCHOR_SEED)
km <- kmeans(km_input, centers = ANCHOR_K, nstart = 25, iter.max = 50)

new_centroids <- tibble(cluster_id = paste0("C", seq_len(ANCHOR_K))) %>%
  bind_cols(as_tibble(km$centers))

message("\nCluster centroids in z-axis space:")
print(new_centroids)
message(sprintf("Within-SS / Total-SS = %.3f",
                km$tot.withinss / km$totss))

# ============================================================
# 3. Name clusters by rule (unchanged from previous pipeline)
# ============================================================
elongated_id <- new_centroids %>%
  slice_max(z_elong, n = 1, with_ties = FALSE) %>% pull(cluster_id)
remaining    <- new_centroids %>% filter(cluster_id != elongated_id)

spread_id    <- remaining %>%
  slice_max(z_size, n = 1, with_ties = FALSE) %>% pull(cluster_id)
remaining    <- remaining %>% filter(cluster_id != spread_id)

small_id     <- remaining %>%
  slice_max(z_round, n = 1, with_ties = FALSE) %>% pull(cluster_id)
ramified_id  <- setdiff(remaining$cluster_id, small_id)

state_anchors <- new_centroids %>%
  mutate(state_name = case_when(
    cluster_id == elongated_id ~ "Elongated",
    cluster_id == spread_id    ~ "Spread",
    cluster_id == small_id     ~ "Small_Round",
    cluster_id == ramified_id  ~ "Ramified"
  )) %>%
  select(state_name, all_of(state_axes))

message("\n========== Canonical state anchors ==========")
print(state_anchors)

# ============================================================
# 4. Silhouette analysis (k = 2..8) for FigS3 justification
# ============================================================
message("\n========== Silhouette analysis (k=2..8) ==========")
message("Computing on a 5,000-cell random subsample for tractable dist()")

set.seed(ANCHOR_SEED)
subsample_idx <- sample(seq_len(nrow(km_input)),
                        size = min(5000, nrow(km_input)))
km_sub <- km_input[subsample_idx, ]
d_sub  <- dist(km_sub)

sil_scores <- sapply(2:8, function(k) {
  set.seed(ANCHOR_SEED)
  km_k <- kmeans(km_sub, centers = k, nstart = 25, iter.max = 50)
  mean(silhouette(km_k$cluster, d_sub)[, "sil_width"])
})

silhouette_df <- tibble(k = 2:8, silhouette = round(sil_scores, 3))
message("Silhouette scores:")
print(silhouette_df)
message(sprintf("Silhouette-optimal k = %d (local optima: k=4 is %.3f)",
                silhouette_df$k[which.max(silhouette_df$silhouette)],
                silhouette_df$silhouette[silhouette_df$k == 4]))

# Also store k=2 and k=3 cluster assignments on the subsample,
# so FigS3 can show "what happens if we use k=2 or k=3"
set.seed(ANCHOR_SEED)
km_k2 <- kmeans(km_sub, centers = 2, nstart = 25, iter.max = 50)
set.seed(ANCHOR_SEED)
km_k3 <- kmeans(km_sub, centers = 3, nstart = 25, iter.max = 50)

# Map each subsampled cell through the k=ANCHOR_K clustering as well
# so we can cross-tabulate "k=4 state" vs "k=2 / k=3 cluster"
k4_labels_sub <- km$cluster[subsample_idx]
k4_state_sub  <- setNames(state_anchors$state_name,
                          paste0("C", seq_len(ANCHOR_K)))[paste0("C", k4_labels_sub)]

diagnostic <- tibble(
  State_final = factor(k4_state_sub,
                       levels = c("Elongated","Spread","Ramified","Small_Round")),
  k2_cluster  = paste0("k2_C", km_k2$cluster),
  k3_cluster  = paste0("k3_C", km_k3$cluster)
)

saveRDS(
  list(
    silhouette  = silhouette_df,
    diagnostic  = diagnostic,
    subsample_n = nrow(km_sub),
    seed        = ANCHOR_SEED
  ),
  SILHOUETTE_FILE
)
message(sprintf("Saved: %s", SILHOUETTE_FILE))

scaling_params <- tibble(
  axis = c("z_elong", "z_size", "z_round"),
  mean = c(mean(anchor_with_axes$Elongation),
           mean(anchor_with_axes$SizeProxy),
           mean(anchor_with_axes$RoundnessProxy)),
  sd   = c(sd(anchor_with_axes$Elongation),
           sd(anchor_with_axes$SizeProxy),
           sd(anchor_with_axes$RoundnessProxy))
)
saveRDS(list(anchors = state_anchors, scaling = scaling_params),
        "R/state_anchors.rds")

message("\n========== define_state_anchors.R complete ==========")