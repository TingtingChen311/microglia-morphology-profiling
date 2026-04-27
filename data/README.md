# Data — directory structure and download instructions

This directory is **empty in the GitHub repository** because raw and intermediate data exceed GitHub's file-size limits. All data are archived on Zenodo / BioImage Archive and must be downloaded separately before running the analysis.

---

## Where to download

| Resource | Approx. size | Archive | DOI / Accession |
|----------|--------------|---------|-----------------|
| Raw phase-contrast images (Incucyte S3) | ~XX GB | BioImage Archive *(or Zenodo)* | `S-BIADXXX` *(or 10.5281/zenodo.XXXXXXX)* |
| CellROX deep-red fluorescence images | ~X GB | same as above | same as above |
| Cellpose-SAM segmentation masks | ~XX GB | Zenodo | `10.5281/zenodo.XXXXXXX` |
| CellProfiler per-cell measurement CSVs | ~X GB | Zenodo | `10.5281/zenodo.XXXXXXX` |

> **Note for the authors:** replace placeholders (`XX GB`, `S-BIADXXX`, the three `XXXXXXX` IDs) with the values you receive after upload. If everything goes to a single Zenodo record, collapse the rows accordingly.

After download, extract the archives **into this `data/` folder** so that the structure matches the layout below.

---

## Expected directory layout

```
data/
├── raw_images/                          # phase-contrast TIFFs from Incucyte S3
│   ├── Exp1/
│   │   ├── Vehicle/
│   │   │   ├── well_<ID>_field01_t00h.tif
│   │   │   ├── well_<ID>_field01_t02h.tif
│   │   │   └── …                        # 13 time points × 2 fields × N wells
│   │   ├── LPS/
│   │   ├── IFNg/
│   │   ├── IL1b/
│   │   ├── IL6/
│   │   ├── TNFa/
│   │   └── LPS_IFNg/
│   ├── Exp2/                             # same internal structure
│   └── Exp3/                             # same internal structure
│
├── ros_images/                           # CellROX deep-red, 24 h endpoint only
│   ├── Exp1/{Vehicle,LPS,IFNg,IL1b,IL6,TNFa}/…
│   ├── Exp2/…
│   └── Exp3/…
│
├── masks/                                # Cellpose-SAM output (mirrors raw_images/)
│   ├── Exp1/…
│   ├── Exp2/…
│   └── Exp3/…
│
└── cellprofiler_output/                  # per-cell measurements (CSV)
    ├── Exp1/
    │   ├── MyExpt_Image.csv
    │   └── MyExpt_FilteredCells.csv      # or whatever the pipeline names them
    ├── Exp2/
    └── Exp3/
```

---

## Filename convention

Image files follow:

```
well_<wellID>_field<NN>_t<HH>h.tif
```

- `<wellID>` — 96-well plate position (e.g., `B03`)
- `<NN>` — Incucyte field number; **only fields 01 and 03** are used downstream (Methods: *Live-cell imaging*)
- `<HH>` — time post-stimulation in hours; values: `00, 02, 04, …, 24` (13 time points)

---

## Experimental design summary

| Variable | Levels |
|----------|--------|
| Independent differentiation runs | Exp1, Exp2, Exp3 *(n = 3 biological replicates)* |
| Treatments (time-course experiment) | Vehicle, LPS, IFNγ, IL-1β, IL-6, TNFα, LPS+IFNγ |
| Treatments (ROS endpoint experiment) | Vehicle, LPS, IFNγ, IL-1β, IL-6, TNFα |
| Time points (time-course) | 0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24 h *(13 total)* |
| Time point (ROS) | 24 h endpoint only |
| Wells per condition | 3 |
| Fields per well analyzed | 2 (fields 01 and 03) |

**Treatment concentrations** (Methods: *Inflammatory stimulation*):

- LPS: 50 ng/mL
- IFNγ: 100 ng/mL
- IL-1β: 10 ng/mL
- IL-6: 100 ng/mL
- TNFα: 50 ng/mL
- LPS+IFNγ co-stimulation: 50 + 100 ng/mL

Vehicle controls received an equivalent volume of cytokine reconstitution buffer (0.1% BSA in sterile water).

---

## Notes on data scope

- Only the **IL-34–supplemented** condition is included here. The IL-34– arm was acquired in parallel and is reported elsewhere.
- A small fraction of images (those with < 20 cells after segmentation and filtering) are excluded at the analysis stage, not at the data-archiving stage; raw images are provided in full.

---

## Verifying integrity after download

If the Zenodo record provides MD5 checksums (it usually does), verify with:

```bash
cd data
md5sum -c checksums.md5
```

If you encounter any issues with the archive, please open an issue on the GitHub repository or contact t.chen@rug.nl.
