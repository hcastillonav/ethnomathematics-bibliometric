# Data documentation

## Important note on data availability

The raw Scopus CSV export (`data_ethno.csv`) **is not included** in this
repository because Scopus data is subject to Elsevier's terms of use and
cannot be redistributed publicly.

To replicate this study, you must export the corpus directly from Scopus
using the search equation documented in `docs/search_equation.md`.

## Files included in this folder

### `mis_cluster.txt`

VOSviewer node-level cluster export. Tab-separated text file containing
one row per keyword retained in the co-occurrence network.

**Columns:**

| Column | Description |
|---|---|
| `id` | VOSviewer internal node identifier |
| `label` | Keyword text |
| `x` | x-coordinate in the VOSviewer map |
| `y` | y-coordinate in the VOSviewer map |
| `cluster` | Leiden cluster assignment (1–12) |
| `weight<Links>` | Number of co-occurrence links |
| `weight<Total link strength>` | Sum of co-occurrence strengths |
| `weight<Occurrences>` | Number of documents containing the keyword |
| `score<Avg. pub. year>` | Average publication year of documents containing the keyword |
| `score<Avg. citations>` | Average citation count of documents containing the keyword |
| `score<Avg. norm. citations>` | Average normalized citation count |

**Parameters used to generate this file:**
- Minimum occurrences: 3
- Leiden resolution: 0.6
- Counting method: Full counting
- Total keywords: 240

## How to obtain the Scopus CSV

1. Go to [https://www.scopus.com](https://www.scopus.com)
2. Run the search equation from `docs/search_equation.md` in the
   TITLE-ABS-KEY field
3. Select all results
4. Click **Export** → **CSV** → **All available fields**
5. Save the file as `data_ethno.csv` in this `data/` folder
6. Run the main script: `source("R/ethnomathematics_bibliometric_analysis.R")`

## Corpus characteristics (for reference)

| Item | Value |
|---|---|
| Total documents | 922 |
| Year range | 1985–2026 |
| Search date | May 2026 |
| Unique authors | 1,779 |
| Unique keywords | 2,370 |
| Countries | 73 |
| Total citations | 6,126 |
