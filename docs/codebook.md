# Codebook — variable definitions

## Scopus CSV fields used in the analysis

| Variable | Scopus field name | Type | Description |
|---|---|---|---|
| `Year` | Year | Integer | Year of publication |
| `Document_Type` | Document Type | Character | Article, Conference paper, Book chapter, Review, etc. |
| `Affiliations` | Affiliations | Character | Semicolon-separated list of author affiliations |
| `Authors` | Authors | Character | Semicolon-separated list of author names (Last, Initials) |
| `Author_Keywords` | Author Keywords | Character | Semicolon-separated author-supplied keywords |
| `Index_Keywords` | Index Keywords | Character | Semicolon-separated database-assigned keywords |
| `Cited_by` | Cited by | Integer | Total citation count at export date |
| `Source_title` | Source title | Character | Journal or proceedings title |
| `EID` | EID | Character | Scopus unique record identifier |

## Derived variables (created in R)

| Variable | Source | Description |
|---|---|---|
| `countries_list` | `Affiliations` | List of countries extracted as the last comma-separated segment of each affiliation entry |
| `country_first` | `countries_list` | Country of the first author's affiliation |
| `kw_list` | `Author_Keywords` | List of individual keywords after splitting on semicolons |
| `auth_list` | `Authors` | List of individual authors after splitting on semicolons |
| `Period` | `Year` | Temporal period: "Before 2010", "2010–2014", "2015–2019", "2020–2026" |
| `doc_short` | `Document_Type` | Simplified document type label for visualization |

## GAM model variables

| Variable | Description |
|---|---|
| `n` | Number of documents published per year (response variable) |
| `Year` | Year of publication (predictor variable) |
| `fit_resp` | Fitted values in response scale (documents/year) |
| `fit_link` | Centered smooth term f(t) on log scale |
| `lwr_resp` / `upr_resp` | 95% CI bounds in response scale |
| `lwr_link` / `upr_link` | 95% CI bounds in log scale |

## VOSviewer cluster export variables

| Variable | Description |
|---|---|
| `label` | Keyword text |
| `cluster` | Leiden cluster assignment (1–12) |
| `occ` | Occurrence count (number of documents containing the keyword) |
| `avg_year` | Average publication year of documents containing the keyword |
| `avg_cit` | Average citation count |
| `macro_id` | Macro-cluster identifier (1–5, assigned by research team) |
| `macro_name` | Macro-cluster name |
| `occ_norm` | Occurrence normalized to maximum within macro-cluster (0–1) |

## Macro-cluster coding

| `macro_id` | `macro_name` | Leiden clusters |
|---|---|---|
| 1 | Teaching & Learning | 1, 4 |
| 2 | Ethnomodelling & Critical | 2, 7 |
| 3 | Cultural & Indigenous | 3, 5 |
| 4 | Geometry & Artifacts | 6, 8 |
| 5 | Emerging Trends | 9 |

## Country extraction method

Countries are extracted from the `Affiliations` field by taking the last
comma-separated segment of each semicolon-delimited affiliation entry.

Example:
```
"Universidade Estadual de Campinas, Campinas, Brazil;
 Universitas Pendidikan Indonesia, Bandung, Indonesia"
```
→ extracts `["Brazil", "Indonesia"]`

This method assumes that Scopus formats affiliations as
`[Department,] Institution, City, Country` — which is the standard
Scopus format but may occasionally produce non-country strings for
edge cases. Such values appear in the `country_long` table but are
generally rare and do not affect the top-15 country results.
