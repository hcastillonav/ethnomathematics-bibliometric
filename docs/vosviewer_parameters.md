# VOSviewer parameters

## Software version

VOSviewer 1.6.20
Available at: https://www.vosviewer.com/

## Import procedure

```
File
  → Create
  → Create a map based on bibliographic data
  → Read data from bibliographic database files
  → Scopus
  → [select exported CSV file]
```

## Analysis parameters

| Parameter | Value | Justification |
|---|---|---|
| Analysis type | Co-occurrence | Maps conceptual relationships between terms |
| Unit of analysis | All keywords | Author + index keywords combined |
| Counting method | Full counting | Reflects absolute co-occurrence frequency (Perianes-Rodriguez et al., 2016) |
| Minimum number of occurrences | 3 | Appropriate for corpora of 500–1,500 documents (van Eck & Waltman, 2010) |

## Keyword filtering

| Step | Value |
|---|---|
| Total unique keywords identified | 2,370 |
| Keywords meeting occurrence threshold (≥ 3) | 240 |
| Keywords selected by total link strength | 240 |
| Terms excluded manually | `cross-cultural`, `educators` |

The two manually excluded terms were removed due to their high semantic
breadth and low field specificity. Their inclusion would have introduced
spurious connections between thematically distant clusters.

## Clustering parameters

| Parameter | Value | Justification |
|---|---|---|
| Algorithm | Leiden | Guarantees well-connected communities (Traag et al., 2019) |
| Resolution | 0.6 | Default (1.0) produced 32 clusters including 9 singletons — artefact of high-resolution partitioning in moderately sized networks (Fortunato & Barthélemy, 2007) |
| Leiden clusters obtained | 12 | Algorithmically derived |
| Residual clusters excluded | 3 (clusters 10, 11, 12) | Total link strength ≤ 3; insufficient internal connectivity |
| Thematic macro-clusters | 5 | Semantic grouping by research team |

## Macro-cluster composition

| Macro-cluster | Leiden clusters | N keywords |
|---|---|---|
| Teaching & Learning | 1, 4 | 95 |
| Ethnomodelling & Critical | 2, 7 | 66 |
| Cultural & Indigenous | 3, 5 | 43 |
| Geometry & Artifacts | 6, 8 | 23 |
| Emerging Trends | 9 | 9 |

## Visualizations generated

Three complementary visualizations were exported from VOSviewer:

| Visualization | Description | Paper figure |
|---|---|---|
| Network Visualization | Keyword nodes sized by frequency; edges weighted by co-occurrence strength; colors = Leiden clusters | Figure 7 |
| Overlay Visualization | Same structure; node color encodes average publication year (2016–2024 gradient) | Figure 8 |
| Density Visualization | Heat map of accumulated co-occurrence strength | Figure 9 |

## Cluster export

The node-level data (label, cluster, occurrences, link strength, average
publication year, average citations) was exported from VOSviewer as a
tab-separated text file (`mis_cluster.txt`) and used as input for the
radar chart (Figure 5) generated in R.

## References

- Fortunato, S., & Barthélemy, M. (2007). Resolution limit in community
  detection. *PNAS*, 104(1), 36–41. https://doi.org/10.1073/pnas.0605965104

- Perianes-Rodriguez, A., Waltman, L., & van Eck, N. J. (2016).
  Constructing bibliometric networks: A comparison between full and
  fractional counting. *Journal of Informetrics*, 10(4), 1178–1195.
  https://doi.org/10.1016/j.joi.2016.10.006

- Traag, V. A., Waltman, L., & van Eck, N. J. (2019). From Louvain to
  Leiden: guaranteeing well-connected communities. *Scientific Reports*,
  9(1), 5233. https://doi.org/10.1038/s41598-019-41695-z

- van Eck, N. J., & Waltman, L. (2010). Software survey: VOSviewer, a
  computer program for bibliometric mapping. *Scientometrics*, 84(2),
  523–538. https://doi.org/10.1007/s11192-009-0146-3
