# Tracing the Intellectual Structure of Ethnomathematics Through Keyword Co-occurrence Mapping and Statistical Modeling of Scientific Production

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![R Version](https://img.shields.io/badge/R-%3E%3D4.3.0-blue)](https://www.r-project.org/)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.XXXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXXX)
[![Journal](https://img.shields.io/badge/Target-IJSME%20Springer-orange)](https://link.springer.com/journal/10763)

---

## About this repository

This repository contains the complete analytical pipeline — R scripts, VOSviewer parameters, data documentation, and reproducible outputs — for the bibliometric mapping study:

> **Rodríguez-Nieto, C. A., Castillo-Navarro, H., & Sudirman, S.** (2026). *Tracing the Intellectual Structure of Ethnomathematics Through Keyword Co-occurrence Mapping and Statistical Modeling of Scientific Production.* International Journal of Science and Mathematics Education. *(under review)*

The pipeline is designed to be fully replicable: any researcher can apply it to a new Scopus CSV export — on ethnomathematics or any other field — by changing a single line in the configuration section of the main script.

---

## Study overview

| Item | Detail |
|---|---|
| Database | Scopus |
| Search operator | TITLE-ABS-KEY |
| Search terms | 14 terms (see `docs/search_equation.md`) |
| Corpus | 922 documents · 1985–2026 |
| Bibliometric tool | VOSviewer 1.6.20 |
| Co-occurrence method | All keywords · Full counting |
| Occurrence threshold | 3 |
| Leiden resolution | 0.6 |
| Keywords retained | 240 of 2,370 unique terms |
| Leiden clusters | 12 → 5 thematic macro-clusters |
| Statistical model | GAM Poisson · REML · k = 8 |
| GAM results | edf = 5.94 · χ² = 895.47 · p < 0.001 · Dev. expl. = 94.3% |
| R version | 4.4.x |
| Target journal | International Journal of Science and Mathematics Education (Springer) |

---

## Repository structure

```
ethnomathematics-bibliometric/
│
├── R/
│   ├── ethnomathematics_bibliometric_analysis.R   # Main analysis script
│   └── fig5_radar_macro_clusters_block.R          # Radar chart block (Figure 5)
│
├── data/
│   ├── README_data.md                             # Data documentation
│   └── mis_cluster.txt                            # VOSviewer cluster export
│
├── outputs/
│   ├── figures/                                   # All generated figures (PNG, 300 dpi)
│   └── tables/                                    # All generated CSV tables
│
├── docs/
│   ├── search_equation.md                         # Full Scopus search equation
│   ├── vosviewer_parameters.md                    # VOSviewer configuration
│   └── codebook.md                                # Variable definitions
│
├── LICENSE                                        # MIT License
├── README.md                                      # This file
└── CITATION.cff                                   # Citation metadata
```

---

## How to use this pipeline

### Requirements

Install the following R packages before running the script:

```r
install.packages(c(
  "tidyverse",    # data wrangling and ggplot2
  "mgcv",         # GAM Poisson modeling
  "ggrepel",      # non-overlapping labels
  "scales",       # axis formatting
  "patchwork",    # multi-panel figures
  "RColorBrewer"  # color palettes
))
```

### Step 1 — Export your corpus from Scopus

1. Run your search in [Scopus](https://www.scopus.com) using the equation in `docs/search_equation.md`
2. Select all results → Export → CSV → All available fields
3. Save the file as `data_ethno.csv` (or any name you prefer)

### Step 2 — Configure the script

Open `R/ethnomathematics_bibliometric_analysis.R` and edit the two lines at the top:

```r
INPUT_FILE  <- "data_ethno.csv"    # path to your Scopus CSV
OUTPUT_DIR  <- "outputs"           # folder where figures and tables will be saved
```

### Step 3 — Run the full pipeline

```r
source("R/ethnomathematics_bibliometric_analysis.R")
```

The script will generate all figures and tables automatically and print the GAM results to the console.

### Step 4 — VOSviewer analysis

1. Open VOSviewer 1.6.20
2. Go to `File → Create → Create a map based on bibliographic data → Read data from bibliographic database files → Scopus`
3. Apply the parameters documented in `docs/vosviewer_parameters.md`
4. Export the cluster map as `mis_cluster.txt` and place it in the `data/` folder
5. Run the radar chart block: `source("R/fig5_radar_macro_clusters_block.R")`

---

## Outputs generated

### Figures

| File | Description | Paper reference |
|---|---|---|
| `fig1_annual_production_gam.png` | Annual production + GAM Poisson trend | Figure 1 |
| `fig2_country_doctype.png` | Top 15 countries + document type donut | Figure 2 |
| `fig3_country_by_doctype_stacked.png` | Country × document type stacked bar | Figure 3 |
| `fig4_country_rank_by_period.png` | Country ranking bump chart by period | Figure 4 |
| `fig5_radar_macro_clusters.png` | Keyword profiles by macro-cluster (radar) | Figure 5 |
| `fig6_gam_trend.png` | GAM trend — response scale + f(t) log scale | Figure 6 |
| `figS1_gam_diagnostics.png` | GAM diagnostic plots | Supplementary Figure S1 |

VOSviewer visualizations (Figures 7, 8, 9 — Network, Overlay, Density) are generated directly in VOSviewer and exported as screenshots.

### Tables

| File | Description | Paper reference |
|---|---|---|
| `table_01_summary.csv` | Corpus summary statistics | Table 1 |
| `table_02_doc_types.csv` | Document type distribution | Table 2 |
| `table_03_top_sources.csv` | Top 10 publication sources | Supplementary Table S1 |
| `table_04_top_countries.csv` | Top 15 countries | Table 4 |
| `table_05_top_authors.csv` | Top 15 authors | Table 5 |
| `table_06_top_keywords.csv` | Top 20 author keywords | — |
| `table_07_gam_statistics.csv` | GAM model statistics | Table 3 |
| `table_08_macro_clusters.csv` | Thematic macro-clusters summary | Table 6 |

---

## GAM Poisson model — key results

```
Model: n ~ s(Year, k = 8)
Family: Poisson (log link)
Method: REML

Smooth term s(Year):
  edf     = 5.940
  Chi-sq  = 895.469
  p-value < 0.001

Model fit:
  Deviance explained = 94.3%
  R² (adjusted)      = 0.899
  Overdispersion φ̂  = 2.606  →  quasi-Poisson robustness check applied
```

The effective degrees of freedom (edf = 5.94) confirm a strongly nonlinear growth trajectory. The field shows minimal production before 2012, moderate growth through 2017, and a marked acceleration from 2018 onward, with an estimated inflection point at approximately 2018.

---

## VOSviewer parameters

Full parameters documented in `docs/vosviewer_parameters.md`. Summary:

| Parameter | Value | Justification |
|---|---|---|
| Analysis type | Co-occurrence | Keyword co-occurrence network |
| Counting method | Full counting | Absolute co-occurrence frequency |
| Min. occurrences | 3 | van Eck & Waltman (2010) |
| Leiden resolution | 0.6 | Fortunato & Barthélemy (2007) |
| Keywords retained | 240 / 2,370 | Threshold + link strength filter |
| Leiden clusters | 12 | Algorithmically derived |
| Macro-clusters | 5 | Semantic grouping by authors |
| Excluded terms | cross-cultural, educators | High semantic breadth, low specificity |

---

## Citation

If you use this pipeline in your research, please cite:

```bibtex
@article{RodriguezNieto2026Ethnomathematics,
  author  = {Rodríguez-Nieto, Camilo Andrés and Castillo-Navarro, Harold
             and Sudirman, Sudirman},
  title   = {Tracing the Intellectual Structure of Ethnomathematics Through
             Keyword Co-occurrence Mapping and Statistical Modeling of
             Scientific Production},
  journal = {International Journal of Science and Mathematics Education},
  year    = {2026},
  note    = {Under review}
}
```

---

## Authors

| Author | Affiliation | ORCID |
|---|---|---|
| Camilo Andrés Rodríguez-Nieto | *(affiliation)* | *(ORCID)* |
| Harold Castillo-Navarro | *(affiliation)* | *(ORCID)* |
| Sudirman Sudirman | *(affiliation)* | *(ORCID)* |

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

## Acknowledgements

The authors thank the open-source communities behind R, VOSviewer, ggplot2, and mgcv, whose tools made this analysis possible.
