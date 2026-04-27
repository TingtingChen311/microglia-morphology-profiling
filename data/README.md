# Data

This directory contains small plate-level metadata files that document the experimental design and are tracked in GitHub:

- `Exp1_Metadata.csv`
- `Exp2_Metadata.csv`
- `Exp3_Metadata.csv`
- `24h_ROS_Metadata.csv`

Large raw and intermediate data files are not stored in the GitHub repository because they exceed practical repository size limits. These files will be archived separately on Zenodo and/or BioImage Archive.

## External data archives

| Resource | Approx. size | Archive | DOI / Accession |
|---|---:|---|---|
| Raw phase-contrast images | to be added | BioImage Archive / Zenodo | to be added |
| Cellpose-SAM segmentation masks | to be added | Zenodo | to be added |
| CellProfiler per-cell measurement CSVs | to be added | Zenodo | to be added |

After publication of the archive record, replace the placeholders above with the final DOI or accession numbers.

## Expected local layout

After downloading and extracting the archived data, the local `data/` directory should contain the metadata files plus the downloaded analysis inputs, for example:

```text
data/
├── README.md
├── Exp1_Metadata.csv
├── Exp2_Metadata.csv
├── Exp3_Metadata.csv
├── 24h_ROS_Metadata.csv
├── raw_images/
├── filtered_images/
├── masks/
└── cellprofiler_output/
The exact downloaded folder names may differ depending on the archive package, but the paths used by the analysis scripts should be kept consistent with R/load_and_preprocess.R and the R Markdown files in analyses/.

Files intentionally excluded from GitHub

The repository .gitignore excludes large CellProfiler CSV outputs and image-derived data products, including per-cell measurement tables, raw images, filtered images, and segmentation masks. This prevents accidental upload of large data files while keeping the metadata files version-controlled.

Reproducibility note

The analysis scripts expect the CellProfiler output files to be available locally before running run_all.R. The metadata files included here provide the plate layout and condition annotations required to reproduce the analyses.
