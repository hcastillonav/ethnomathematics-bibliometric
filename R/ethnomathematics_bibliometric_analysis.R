# =============================================================================
# ETHNOMATHEMATICS BIBLIOMETRIC ANALYSIS — Complete Pipeline
# =============================================================================
#
# Paper: "Tracing the Intellectual Structure of Ethnomathematics Through
#         Keyword Co-occurrence Mapping and Statistical Modeling of
#         Scientific Production"
# Authors: Rodríguez-Nieto C.A., Castillo-Navarro H., Sudirman S.
# Target: International Journal of Science and Mathematics Education (Springer)
# Repository: https://github.com/hcastillonav/ethnomathematics-bibliometric
#
# FIGURE AND TABLE MAP — aligned to final paper structure:
#
#   MAIN BODY
#   Figure 1   = Flowchart (built in diagram software — not generated here)
#   Table 1    = Inclusion/exclusion criteria (in manuscript — not generated here)
#   Table 2    = Summary statistics of the Scopus corpus
#   Table 3    = Document type distribution
#   Figure 2   = Annual production + GAM Poisson trend
#   Table 4    = GAM Poisson model statistics
#   Figure 3   = GAM two-panel (response scale + smooth term f(t))
#   Table 5    = Top 15 countries
#   Figure 4   = Geographic distribution + document type donut
#   Figure 5   = Country × document type stacked bar
#   Figure 6   = Country ranking bump chart by period
#   Table 6    = Top 15 most prolific authors
#   Table 7    = Thematic macro-clusters summary
#   Figure 7   = VOSviewer Network Visualization (exported from VOSviewer)
#   Figure 8   = Keyword radar profiles by macro-cluster
#   Figure 9   = VOSviewer Overlay Visualization (exported from VOSviewer)
#   Figure 10  = VOSviewer Density Visualization (exported from VOSviewer)
#   Table 8    = Representative 2025 documents (in manuscript)
#
#   SUPPLEMENTARY MATERIAL
#   Suppl. Table S1   = Top 10 source journals and proceedings
#   Suppl. Figure S1  = GAM Poisson diagnostic plots
#   Appendix 7.1      = VOSviewer interpretation guide (in manuscript)
#
# HOW TO USE:
#   1. Export corpus from Scopus as CSV (all fields) → save to data/data_ethno.csv
#   2. Export VOSviewer cluster map → save to data/mis_cluster.txt
#   3. Edit INPUT_FILE, VOS_FILE, OUTPUT_DIR below if needed
#   4. Run: source("R/ethnomathematics_bibliometric_analysis.R")
#
# REQUIREMENTS (install once):
#   install.packages(c("tidyverse","mgcv","ggrepel","scales","patchwork","RColorBrewer"))
# =============================================================================


# -----------------------------------------------------------------------------
# 0. CONFIGURATION
# -----------------------------------------------------------------------------

INPUT_FILE  <- "data/data_ethno.csv"
VOS_FILE    <- "data/mis_cluster.txt"
OUTPUT_DIR  <- "outputs"


# -----------------------------------------------------------------------------
# 1. SETUP
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
  library(mgcv)
  library(ggrepel)
  library(scales)
  library(patchwork)
  library(RColorBrewer)
})

FIG <- file.path(OUTPUT_DIR, "figures")
TAB <- file.path(OUTPUT_DIR, "tables")
dir.create(FIG, recursive = TRUE, showWarnings = FALSE)
dir.create(TAB, recursive = TRUE, showWarnings = FALSE)

col_bar <- "#2C5F8A"
col_gam <- "#D85A30"

cat("\n========================================================\n")
cat("  ETHNOMATHEMATICS BIBLIOMETRIC ANALYSIS\n")
cat("  Rodríguez-Nieto, Castillo-Navarro & Sudirman (2026)\n")
cat("========================================================\n\n")


# -----------------------------------------------------------------------------
# 2. DATA LOADING AND PREPROCESSING
# -----------------------------------------------------------------------------

cat("[1/9] Loading and preprocessing Scopus data...\n")

raw <- read_csv(INPUT_FILE, show_col_types = FALSE)
cat(sprintf("  > Raw records: %d\n", nrow(raw)))

df <- raw %>%
  filter(!is.na(Year), Year >= 1980,
         Year <= as.integer(format(Sys.Date(), "%Y"))) %>%
  mutate(
    Year          = as.integer(Year),
    Cited_by      = suppressWarnings(as.numeric(`Cited by`)),
    Cited_by      = replace_na(Cited_by, 0),
    Document_Type = replace_na(`Document Type`, "Unknown")
  )

cat(sprintf("  > After filter: %d records (%d–%d)\n",
            nrow(df), min(df$Year), max(df$Year)))

# Country extraction: last comma-segment of each affiliation entry
extract_countries <- function(aff_vec) {
  map(aff_vec, function(aff) {
    if (is.na(aff)) return(character(0))
    entries <- str_split(aff, ";")[[1]]
    map_chr(entries, function(e) {
      parts <- str_split(str_trim(e), ",")[[1]]
      str_trim(tail(parts, 1))
    })
  })
}
df <- df %>% mutate(countries_list = extract_countries(Affiliations))

country_long <- df %>%
  select(EID, Year, Document_Type, Cited_by, countries_list) %>%
  unnest(countries_list) %>%
  rename(country = countries_list) %>%
  filter(!is.na(country), country != "")

# Keyword parsing
parse_kw <- function(kw_vec) {
  map(kw_vec, function(kw) {
    if (is.na(kw)) return(character(0))
    str_trim(str_split(kw, ";")[[1]])
  })
}
df <- df %>% mutate(kw_list = parse_kw(`Author Keywords`))

kw_long <- df %>%
  select(EID, Year) %>%
  bind_cols(tibble(kw_list = df$kw_list)) %>%
  unnest(kw_list) %>%
  rename(keyword = kw_list) %>%
  filter(!is.na(keyword), keyword != "") %>%
  mutate(keyword = str_to_lower(str_trim(keyword)))

# Author parsing
parse_auth <- function(a_vec) {
  map(a_vec, function(a) {
    if (is.na(a)) return(character(0))
    str_trim(str_split(a, ";")[[1]])
  })
}
df <- df %>% mutate(auth_list = parse_auth(Authors))

author_long <- df %>%
  select(EID, Year, Cited_by) %>%
  bind_cols(tibble(auth_list = df$auth_list)) %>%
  unnest(auth_list) %>%
  rename(author = auth_list) %>%
  filter(!is.na(author), author != "")

cat(sprintf("  > Countries: %d mentions · %d unique\n",
            nrow(country_long), n_distinct(country_long$country)))
cat(sprintf("  > Keywords : %d tokens · %d unique\n",
            nrow(kw_long), n_distinct(kw_long$keyword)))
cat("  > Preprocessing complete.\n\n")

# Derived summaries
doc_type_tab <- df %>%
  count(Document_Type, name = "n") %>%
  mutate(pct = round(100 * n / sum(n), 1)) %>%
  arrange(desc(n))

top_countries <- country_long %>%
  count(country, name = "n") %>%
  arrange(desc(n)) %>%
  slice_head(n = 15)

top_authors <- author_long %>%
  count(author, name = "n") %>%
  arrange(desc(n)) %>%
  slice_head(n = 15)

top_keywords <- kw_long %>%
  count(keyword, name = "n") %>%
  arrange(desc(n)) %>%
  slice_head(n = 20)

top_sources <- df %>%
  count(`Source title`, name = "n") %>%
  arrange(desc(n)) %>%
  slice_head(n = 10)

# --- TABLE 2: Summary statistics of the Scopus corpus -----------------------
table2 <- tibble(
  Metric = c("Total documents", "Year range", "Total citations",
             "Mean citations per document", "Median citations per document",
             "Unique authors", "Unique author keywords", "Unique countries"),
  Value  = c(
    nrow(df),
    paste(min(df$Year), max(df$Year), sep = "–"),
    sum(df$Cited_by, na.rm = TRUE),
    round(mean(df$Cited_by, na.rm = TRUE), 2),
    median(df$Cited_by, na.rm = TRUE),
    n_distinct(author_long$author),
    n_distinct(kw_long$keyword),
    n_distinct(country_long$country)
  )
)
write_csv(table2, file.path(TAB, "table_02_summary_statistics.csv"))
cat("  > Saved: table_02_summary_statistics.csv  [Table 2]\n")

# --- TABLE 3: Document type distribution ------------------------------------
write_csv(doc_type_tab, file.path(TAB, "table_03_document_types.csv"))
cat("  > Saved: table_03_document_types.csv  [Table 3]\n")

# --- TABLE 5: Top 15 countries ----------------------------------------------
write_csv(top_countries, file.path(TAB, "table_05_top_countries.csv"))
cat("  > Saved: table_05_top_countries.csv  [Table 5]\n")

# --- TABLE 6: Top 15 authors ------------------------------------------------
write_csv(top_authors, file.path(TAB, "table_06_top_authors.csv"))
cat("  > Saved: table_06_top_authors.csv  [Table 6]\n")

# --- TABLE 6 top keywords (internal use) ------------------------------------
write_csv(top_keywords, file.path(TAB, "internal_top_keywords.csv"))

# --- SUPPLEMENTARY TABLE S1: Top 10 sources ---------------------------------
write_csv(top_sources, file.path(TAB, "suppl_table_S1_top_sources.csv"))
cat("  > Saved: suppl_table_S1_top_sources.csv  [Supplementary Table S1]\n\n")

print(table2)
cat("\n")


# =============================================================================
# FIGURE 2 — Annual scientific production + GAM Poisson trend
# Results section 3.1
# =============================================================================

cat("[2/9] GAM Poisson — fitting model...\n")

docs_per_year <- df %>% count(Year, name = "n") %>% arrange(Year)

modelo_gam <- gam(
  n ~ s(Year, k = 8),
  data   = docs_per_year,
  family = poisson(link = "log"),
  method = "REML"
)

gam_sum <- summary(modelo_gam)
phi_hat <- sum(residuals(modelo_gam, type = "pearson")^2) / modelo_gam$df.residual

cat("  ── GAM Results ──────────────────────────────────────\n")
cat(sprintf("  edf                : %.4f\n",  gam_sum$s.table[1, "edf"]))
cat(sprintf("  Chi-sq             : %.4f\n",  gam_sum$s.table[1, "Chi.sq"]))
cat(sprintf("  p-value            : %.6f\n",  gam_sum$s.table[1, "p-value"]))
cat(sprintf("  Deviance explained : %.1f%%\n", gam_sum$dev.expl * 100))
cat(sprintf("  R² (adjusted)      : %.4f\n",  gam_sum$r.sq))
cat(sprintf("  Overdispersion φ̂  : %.4f  %s\n", phi_hat,
            ifelse(phi_hat > 1.5,
                   "[WARNING: quasi-Poisson check recommended]",
                   "[OK]")))
cat("  ────────────────────────────────────────────────────\n\n")

# --- TABLE 4: GAM Poisson model statistics -----------------------------------
table4 <- tibble(
  Parameter = c("edf", "Chi_sq_statistic", "p_value",
                "deviance_explained_pct", "r_sq_adjusted",
                "overdispersion_phi"),
  Value = c(
    round(gam_sum$s.table[1, "edf"],     4),
    round(gam_sum$s.table[1, "Chi.sq"],  4),
    round(gam_sum$s.table[1, "p-value"], 6),
    round(gam_sum$dev.expl * 100,        2),
    round(gam_sum$r.sq,                  4),
    round(phi_hat,                       4)
  )
)
write_csv(table4, file.path(TAB, "table_04_gam_statistics.csv"))
cat("  > Saved: table_04_gam_statistics.csv  [Table 4]\n\n")

# Prediction ribbon
year_grid <- tibble(Year = seq(min(docs_per_year$Year),
                               max(docs_per_year$Year)))
pred <- predict(modelo_gam, newdata = year_grid,
                type = "link", se.fit = TRUE)
year_grid <- year_grid %>%
  mutate(
    fit = exp(pred$fit),
    lwr = exp(pred$fit - 1.96 * pred$se.fit),
    upr = exp(pred$fit + 1.96 * pred$se.fit)
  )

cat("[3/9] Figure 2 — Annual production + GAM trend...\n")

p_fig2 <- ggplot() +
  geom_col(data = docs_per_year,
           aes(x = Year, y = n),
           fill = col_bar, alpha = 0.65, width = 0.75) +
  geom_ribbon(data = year_grid,
              aes(x = Year, ymin = lwr, ymax = upr),
              fill = col_gam, alpha = 0.15) +
  geom_line(data = year_grid,
            aes(x = Year, y = fit),
            color = col_gam, linewidth = 1.1) +
  annotate("text",
           x = min(docs_per_year$Year) + 1,
           y = max(docs_per_year$n) * 0.90,
           label = sprintf("GAM Poisson (REML)\nedf = %.2f  ·  p < 0.001\nDev. expl. = %.1f%%\nR² (adj.) = %.3f",
                           gam_sum$s.table[1, "edf"],
                           gam_sum$dev.expl * 100,
                           gam_sum$r.sq),
           hjust = 0, vjust = 1, size = 3.2,
           color = col_gam, lineheight = 1.4) +
  scale_x_continuous(breaks = seq(1985, max(docs_per_year$Year), 5)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
  labs(
    title    = "Annual scientific production on ethnomathematics indexed in Scopus",
    subtitle = paste0("N = ", nrow(df), " documents · ",
                      min(df$Year), "–", max(df$Year)),
    x        = "Year of publication",
    y        = "Number of documents",
    caption  = paste0(
      "Blue bars: observed counts.  ",
      "Orange line: GAM Poisson fitted trend (REML).  ",
      "Shaded band: 95% CI."
    )
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title       = element_text(face = "bold", size = 12),
        plot.subtitle    = element_text(color = "grey45", size = 10),
        plot.caption     = element_text(color = "grey55", size = 8),
        panel.grid.minor = element_blank())

ggsave(file.path(FIG, "figure_02_annual_production_gam.png"),
       p_fig2, width = 11, height = 5.5, dpi = 300)
cat("  > Saved: figure_02_annual_production_gam.png  [Figure 2]\n\n")


# =============================================================================
# FIGURE 3 — GAM two-panel trend (response scale + smooth term f(t))
# Results section 3.2
# =============================================================================

cat("[4/9] Figure 3 — GAM two-panel trend...\n")

year_seq2 <- tibble(Year = seq(min(docs_per_year$Year),
                               max(docs_per_year$Year), by = 0.5))
pred_resp <- predict(modelo_gam, newdata = year_seq2,
                     type = "response", se.fit = TRUE)
pred_link <- predict(modelo_gam, newdata = year_seq2,
                     type = "link",     se.fit = TRUE)

year_seq2 <- year_seq2 %>%
  mutate(
    fit_resp = pred_resp$fit,
    lwr_resp = exp(pred_link$fit - 1.96 * pred_link$se.fit),
    upr_resp = exp(pred_link$fit + 1.96 * pred_link$se.fit),
    fit_link = pred_link$fit - mean(pred_link$fit),
    lwr_link = fit_link - 1.96 * pred_link$se.fit,
    upr_link = fit_link + 1.96 * pred_link$se.fit
  )

fit_vals  <- year_seq2 %>% filter(Year == round(Year)) %>% pull(fit_resp)
fit_years <- year_seq2 %>% filter(Year == round(Year)) %>% pull(Year)
accel_yr  <- fit_years[which.max(diff(diff(fit_vals))) + 1]

gam_ann <- sprintf(
  "GAM Poisson (REML)\nedf = %.2f  ·  χ² = %.1f\np < 0.001  ·  Dev. expl. = %.1f%%\nR² (adj.) = %.3f",
  gam_sum$s.table[1, "edf"],
  gam_sum$s.table[1, "Chi.sq"],
  gam_sum$dev.expl * 100,
  gam_sum$r.sq
)

p3a <- ggplot() +
  geom_ribbon(data = year_seq2,
              aes(x = Year, ymin = lwr_resp, ymax = upr_resp),
              fill = col_gam, alpha = 0.15) +
  geom_line(data = year_seq2,
            aes(x = Year, y = fit_resp),
            color = col_gam, linewidth = 1.3) +
  geom_point(data = docs_per_year,
             aes(x = Year, y = n),
             color = col_bar, size = 2.0, alpha = 0.85) +
  geom_vline(xintercept = accel_yr, linetype = "dashed",
             color = "grey50", linewidth = 0.5) +
  annotate("text", x = accel_yr + 0.4,
           y = max(docs_per_year$n) * 0.55,
           label = paste0("Acceleration\n≈ ", accel_yr),
           hjust = 0, size = 3.0, color = "grey40") +
  annotate("text",
           x = min(docs_per_year$Year) + 1,
           y = max(docs_per_year$n) * 0.90,
           label = gam_ann,
           hjust = 0, vjust = 1, size = 3.0,
           color = col_gam, lineheight = 1.3) +
  scale_x_continuous(breaks = seq(1985, max(docs_per_year$Year), 5)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
  labs(title    = "Fitted GAM trend — response scale",
       subtitle = "Expected documents per year with 95% CI",
       x = "Year of publication", y = "Number of documents") +
  theme_minimal(base_size = 11) +
  theme(plot.title       = element_text(face = "bold", size = 11),
        plot.subtitle    = element_text(color = "grey45", size = 9),
        panel.grid.minor = element_blank(),
        axis.text.x      = element_text(angle = 45, hjust = 1, size = 8))

p3b <- ggplot() +
  geom_hline(yintercept = 0, linetype = "dashed",
             color = "grey60", linewidth = 0.5) +
  geom_ribbon(data = year_seq2,
              aes(x = Year, ymin = lwr_link, ymax = upr_link),
              fill = col_gam, alpha = 0.15) +
  geom_line(data = year_seq2,
            aes(x = Year, y = fit_link),
            color = col_gam, linewidth = 1.3) +
  geom_vline(xintercept = accel_yr, linetype = "dashed",
             color = "grey50", linewidth = 0.5) +
  annotate("text", x = accel_yr + 0.4,
           y = min(year_seq2$lwr_link) * 0.55,
           label = paste0("≈ ", accel_yr),
           hjust = 0, size = 3.0, color = "grey40") +
  scale_x_continuous(breaks = seq(1985, max(docs_per_year$Year), 5)) +
  labs(
    title    = "Smooth term f(t) — log scale",
    subtitle = sprintf("Centered at zero · 95% pointwise CI · edf = %.2f",
                       gam_sum$s.table[1, "edf"]),
    x = "Year of publication",
    y = expression(hat(f)(t) ~ "[log scale, centered]")
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title       = element_text(face = "bold", size = 11),
        plot.subtitle    = element_text(color = "grey45", size = 9),
        panel.grid.minor = element_blank(),
        axis.text.x      = element_text(angle = 45, hjust = 1, size = 8))

p_fig3 <- p3a + p3b +
  plot_annotation(
    title    = "GAM Poisson model of annual scientific production on ethnomathematics",
    subtitle = paste0(
      "N = ", nrow(df), " documents · ",
      min(df$Year), "–", max(df$Year),
      " · Smoother: cubic regression spline, k = 8, REML"
    ),
    caption = paste0(
      "Left: fitted trend in response scale (documents/year). ",
      "Right: smooth term f(t) centered at zero on log scale. ",
      "Shaded band: 95% CI. Dashed line: estimated acceleration point."
    ),
    theme = theme(
      plot.title    = element_text(face = "bold", size = 13, hjust = 0.5),
      plot.subtitle = element_text(color = "grey45", size = 10, hjust = 0.5),
      plot.caption  = element_text(color = "grey55", size = 8, hjust = 0.5,
                                   margin = margin(t = 8))
    )
  )

ggsave(file.path(FIG, "figure_03_gam_trend_panels.png"),
       p_fig3, width = 14, height = 6, dpi = 300)
cat("  > Saved: figure_03_gam_trend_panels.png  [Figure 3]\n\n")


# =============================================================================
# FIGURE 4 — Geographic distribution + document type donut
# Results section 3.3
# =============================================================================

cat("[5/9] Figures 4, 5, 6 — Country analysis...\n")

p4a <- top_countries %>%
  mutate(country = fct_reorder(country, n)) %>%
  ggplot(aes(x = n, y = country)) +
  geom_col(fill = col_bar, alpha = 0.8, width = 0.7) +
  geom_text(aes(label = n), hjust = -0.2, size = 3.1, color = "grey30") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.15))) +
  labs(title    = "Top 15 countries by institutional affiliation",
       subtitle = "All author affiliations per document",
       x = "Affiliation mentions", y = NULL) +
  theme_minimal(base_size = 10) +
  theme(plot.title         = element_text(face = "bold", size = 11),
        panel.grid.major.y = element_blank(),
        panel.grid.minor   = element_blank())

donut_df <- doc_type_tab %>%
  mutate(ymax      = cumsum(pct),
         ymin      = lag(ymax, default = 0),
         label_pos = (ymax + ymin) / 2,
         label     = ifelse(pct >= 3,
                            paste0(Document_Type, "\n", pct, "%"), ""))

cols_d <- colorRampPalette(brewer.pal(9, "Blues")[3:9])(nrow(donut_df))

p4b <- ggplot(donut_df,
              aes(ymax = ymax, ymin = ymin,
                  xmax = 4, xmin = 2.5,
                  fill = Document_Type)) +
  geom_rect(color = "white", linewidth = 0.5) +
  geom_text(aes(x = 4.6, y = label_pos, label = label),
            size = 2.8, hjust = 0, lineheight = 0.9) +
  coord_polar(theta = "y") +
  xlim(c(0, 6)) +
  scale_fill_manual(values = cols_d) +
  labs(title    = "Documents by type",
       subtitle = paste0("N = ", nrow(df))) +
  theme_void(base_size = 10) +
  theme(plot.title      = element_text(face = "bold", size = 11, hjust = 0.5),
        plot.subtitle   = element_text(color = "grey45", size = 9, hjust = 0.5),
        legend.position = "none")

p_fig4 <- p4a | p4b
ggsave(file.path(FIG, "figure_04_geographic_distribution_doctypes.png"),
       p_fig4, width = 14, height = 6, dpi = 300)
cat("  > Saved: figure_04_geographic_distribution_doctypes.png  [Figure 4]\n")


# =============================================================================
# FIGURE 5 — Country × document type stacked bar
# Results section 3.3
# =============================================================================

top8_countries <- top_countries %>% slice_head(n = 8) %>% pull(country)

doc_short <- c(
  "Article"           = "Article",
  "Conference paper"  = "Conf. paper",
  "Book chapter"      = "Book chapter",
  "Review"            = "Review",
  "Conference review" = "Conf. review",
  "Book"              = "Book",
  "Note"              = "Note",
  "Editorial"         = "Editorial",
  "Short survey"      = "Short survey",
  "Erratum"           = "Other",
  "Unknown"           = "Other"
)

country_doctype <- country_long %>%
  filter(country %in% top8_countries) %>%
  mutate(doc_short = recode(Document_Type, !!!doc_short),
         country   = factor(country, levels = rev(top8_countries))) %>%
  count(country, doc_short, name = "n")

p_fig5 <- ggplot(country_doctype,
                 aes(x = n, y = country, fill = doc_short)) +
  geom_col(position = "stack", width = 0.75,
           color = "white", linewidth = 0.3) +
  geom_text(data = country_doctype %>%
              group_by(country) %>%
              summarise(total = sum(n), .groups = "drop"),
            aes(x = total + 5, y = country, label = total),
            inherit.aes = FALSE,
            hjust = 0, size = 3.2, color = "grey30") +
  scale_fill_brewer(palette = "Set2", name = "Document type") +
  scale_x_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(
    title    = "Scientific production by country and document type",
    subtitle = "Top 8 countries by number of affiliation mentions",
    x        = "Number of documents",
    y        = NULL,
    caption  = "A document may be counted in more than one country if its authors hold affiliations in different countries."
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title         = element_text(face = "bold", size = 12),
        plot.subtitle      = element_text(color = "grey45", size = 9),
        plot.caption       = element_text(color = "grey55", size = 8),
        panel.grid.major.y = element_blank(),
        panel.grid.minor   = element_blank(),
        legend.position    = "bottom")

ggsave(file.path(FIG, "figure_05_country_by_doctype_stacked.png"),
       p_fig5, width = 11, height = 6, dpi = 300)
cat("  > Saved: figure_05_country_by_doctype_stacked.png  [Figure 5]\n")


# =============================================================================
# FIGURE 6 — Country ranking bump chart by period
# Results section 3.3
# =============================================================================

top10_countries <- top_countries %>% slice_head(n = 10) %>% pull(country)

bump_data <- country_long %>%
  filter(country %in% top10_countries) %>%
  mutate(Period = case_when(
    Year < 2010               ~ "Before\n2010",
    Year >= 2010 & Year < 2015 ~ "2010–\n2014",
    Year >= 2015 & Year < 2020 ~ "2015–\n2019",
    Year >= 2020               ~ "2020–\n2026"
  )) %>%
  count(Period, country, name = "n") %>%
  group_by(Period) %>%
  mutate(rank = rank(-n, ties.method = "first")) %>%
  ungroup() %>%
  mutate(Period = factor(Period,
                         levels = c("Before\n2010", "2010–\n2014",
                                    "2015–\n2019", "2020–\n2026")))

cols_bump <- colorRampPalette(brewer.pal(10, "Paired"))(10)

p_fig6 <- ggplot(bump_data,
                 aes(x = Period, y = rank,
                     group = country, color = country)) +
  geom_line(linewidth = 1.1, alpha = 0.8) +
  geom_point(aes(size = n), alpha = 0.85) +
  geom_text_repel(
    data    = bump_data %>% filter(Period == "2020–\n2026"),
    aes(label = paste0(country, " (", n, ")")),
    nudge_x = 0.35, hjust = 0, size = 3.0,
    segment.size = 0.3, segment.color = "grey70",
    direction = "y", min.segment.length = 0
  ) +
  scale_y_reverse(breaks = 1:10) +
  scale_size_continuous(range = c(3, 10), name = "Documents") +
  scale_color_manual(values = cols_bump) +
  scale_x_discrete(expand = expansion(add = c(0.3, 1.8))) +
  labs(
    title    = "Country ranking trajectories across four publication periods",
    subtitle = "Top 10 countries — rank by number of document affiliations per period",
    x        = NULL,
    y        = "Rank (1 = most productive)",
    caption  = "Point size proportional to number of documents. Labels show 2020–2026 values."
  ) +
  guides(color = "none") +
  theme_minimal(base_size = 11) +
  theme(plot.title       = element_text(face = "bold", size = 12),
        plot.subtitle    = element_text(color = "grey45", size = 9),
        plot.caption     = element_text(color = "grey55", size = 8),
        panel.grid.minor = element_blank())

ggsave(file.path(FIG, "figure_06_country_ranking_bump.png"),
       p_fig6, width = 12, height = 7, dpi = 300)
cat("  > Saved: figure_06_country_ranking_bump.png  [Figure 6]\n\n")


# =============================================================================
# FIGURE 8 — Keyword radar profiles by thematic macro-cluster
# Results section 3.4
# Note: Figure 7 (VOSviewer Network) is exported directly from VOSviewer
# =============================================================================

cat("[6/9] Figure 8 — Keyword radar by macro-cluster...\n")

if (!file.exists(VOS_FILE)) {
  cat(sprintf("  [SKIP] VOSviewer file not found: %s\n", VOS_FILE))
  cat("  Export the cluster map from VOSviewer and re-run this script.\n\n")
} else {

  vos <- read_tsv(VOS_FILE, show_col_types = FALSE,
                  locale = locale(encoding = "UTF-8")) %>%
    rename(label = label, cluster = cluster,
           occ   = `weight<Occurrences>`) %>%
    select(label, cluster, occ)

  macro_map <- tribble(
    ~cluster, ~macro_id, ~macro_name,
    1, 1, "Teaching &\nLearning",
    4, 1, "Teaching &\nLearning",
    2, 2, "Ethnomodelling\n& Critical",
    7, 2, "Ethnomodelling\n& Critical",
    3, 3, "Cultural &\nIndigenous",
    5, 3, "Cultural &\nIndigenous",
    6, 4, "Geometry &\nArtifacts",
    8, 4, "Geometry &\nArtifacts",
    9, 5, "Emerging\nTrends"
  )

  mc_colors <- c("1" = "#2C5F8A", "2" = "#1D9E75",
                 "3" = "#D85A30", "4" = "#7B4FA6", "5" = "#C0392B")

  exclude_terms <- c("ethnomathematics", "ethnomatematics",
                     "ethnomathematic", "education", "learning",
                     "mathematics", "physics", "copyrights", "article")

  N_KW <- 7

  radar_raw <- vos %>%
    filter(!label %in% exclude_terms) %>%
    inner_join(macro_map, by = "cluster") %>%
    group_by(macro_id, macro_name) %>%
    slice_max(order_by = occ, n = N_KW, with_ties = FALSE) %>%
    mutate(
      occ_norm = occ / max(occ),
      kw_label = paste0(str_to_title(label), "\n(", occ, ")")
    ) %>%
    ungroup()

  radar_coords <- radar_raw %>%
    group_by(macro_id, macro_name) %>%
    mutate(
      n_kw    = n(),
      angle   = (row_number() - 1) / n_kw * 2 * pi,
      x       = occ_norm * cos(angle + pi / 2),
      y       = occ_norm * sin(angle + pi / 2),
      x_label = 1.28 * cos(angle + pi / 2),
      y_label = 1.28 * sin(angle + pi / 2)
    ) %>%
    ungroup()

  radar_poly <- radar_coords %>%
    group_by(macro_id, macro_name) %>%
    group_modify(~ bind_rows(.x, .x[1, ])) %>%
    ungroup()

  grid_rings <- expand_grid(
    macro_id = 1:5,
    r        = c(0.25, 0.5, 0.75, 1.0),
    theta    = seq(0, 2 * pi, length.out = 200)
  ) %>%
    mutate(x = r * cos(theta), y = r * sin(theta)) %>%
    left_join(macro_map %>% distinct(macro_id, macro_name), by = "macro_id")

  spokes <- radar_coords %>%
    select(macro_id, macro_name, angle) %>%
    distinct() %>%
    mutate(x_end = cos(angle + pi / 2),
           y_end = sin(angle + pi / 2))

  p_fig8 <- ggplot() +
    geom_rect(data = radar_coords %>% distinct(macro_id, macro_name),
              aes(xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf),
              fill = "#F5F5F3", color = NA) +
    geom_path(data = grid_rings,
              aes(x = x, y = y, group = interaction(macro_id, r)),
              color = "white", linewidth = 0.5) +
    geom_segment(data = spokes,
                 aes(x = 0, y = 0, xend = x_end, yend = y_end),
                 color = "white", linewidth = 0.4) +
    geom_polygon(data = radar_poly,
                 aes(x = x, y = y,
                     group = interaction(macro_id, macro_name),
                     fill  = factor(macro_id)),
                 alpha = 0.25) +
    geom_path(data = radar_poly,
              aes(x = x, y = y,
                  group = interaction(macro_id, macro_name),
                  color = factor(macro_id)),
              linewidth = 1.8) +
    geom_point(data = radar_coords,
               aes(x = x, y = y, color = factor(macro_id)),
               size = 2.5) +
    geom_text(data = radar_coords,
              aes(x = x_label, y = y_label, label = kw_label),
              size = 2.4, lineheight = 0.88,
              color = "#2C2C2A", fontface = "bold") +
    facet_wrap(~ macro_name, ncol = 3) +
    scale_fill_manual(values  = mc_colors, guide = "none") +
    scale_color_manual(values = mc_colors, guide = "none") +
    coord_fixed(xlim = c(-1.65, 1.65), ylim = c(-1.65, 1.65)) +
    labs(
      title    = "Keyword profiles of the five thematic macro-clusters",
      subtitle = paste0("Top ", N_KW,
                        " keywords per macro-cluster · ",
                        "Values normalized within each cluster · ",
                        "Raw occurrence count in parentheses"),
      caption  = "Macro-clusters derived from 12 Leiden clusters (VOSviewer, resolution = 0.6, threshold = 3)."
    ) +
    theme_void(base_size = 10) +
    theme(
      plot.title      = element_text(face = "bold", size = 13,
                                     hjust = 0.5, margin = margin(b = 4)),
      plot.subtitle   = element_text(color = "grey45", size = 9,
                                     hjust = 0.5, margin = margin(b = 8)),
      plot.caption    = element_text(color = "grey55", size = 7.5,
                                     hjust = 0.5, margin = margin(t = 8)),
      strip.text      = element_text(face = "bold", size = 10,
                                     color = "grey20", margin = margin(b = 6)),
      panel.spacing   = unit(1.8, "cm"),
      plot.background = element_rect(fill = "#FAFAF8", color = NA),
      plot.margin     = margin(12, 20, 12, 20)
    )

  ggsave(file.path(FIG, "figure_08_radar_macro_clusters.png"),
         p_fig8, width = 16, height = 11, dpi = 300)
  cat("  > Saved: figure_08_radar_macro_clusters.png  [Figure 8]\n\n")

  # --- TABLE 7: Macro-clusters summary ---------------------------------------
  macro_map_full <- tribble(
    ~cluster, ~macro_id, ~macro_name,
    1, 1, "Teaching & Learning",
    4, 1, "Teaching & Learning",
    2, 2, "Ethnomodelling & Critical",
    7, 2, "Ethnomodelling & Critical",
    3, 3, "Cultural & Indigenous",
    5, 3, "Cultural & Indigenous",
    6, 4, "Geometry & Artifacts",
    8, 4, "Geometry & Artifacts",
    9, 5, "Emerging Trends"
  )
  macro_order <- c("Teaching & Learning", "Ethnomodelling & Critical",
                   "Cultural & Indigenous", "Geometry & Artifacts",
                   "Emerging Trends")

  vos_full <- read_tsv(VOS_FILE, show_col_types = FALSE,
                       locale = locale(encoding = "UTF-8")) %>%
    rename(label = label, cluster = cluster,
           occ      = `weight<Occurrences>`,
           avg_year = `score<Avg. pub. year>`,
           avg_cit  = `score<Avg. citations>`) %>%
    select(label, cluster, occ, avg_year, avg_cit)

  vos_mapped <- vos_full %>% inner_join(macro_map_full, by = "cluster")

  table7 <- vos_mapped %>%
    group_by(macro_id, macro_name) %>%
    summarise(
      leiden_clusters   = paste(sort(unique(cluster)), collapse = ", "),
      n_keywords        = n(),
      total_occurrences = sum(occ),
      mean_pub_year     = round(mean(avg_year, na.rm = TRUE), 1),
      mean_citations    = round(mean(avg_cit,  na.rm = TRUE), 1),
      .groups = "drop"
    ) %>%
    left_join(
      vos_mapped %>%
        filter(!label %in% exclude_terms) %>%
        group_by(macro_id) %>%
        slice_max(order_by = occ, n = 6, with_ties = FALSE) %>%
        summarise(top_keywords = paste(str_to_title(label),
                                       collapse = "; "),
                  .groups = "drop"),
      by = "macro_id"
    ) %>%
    mutate(macro_name = factor(macro_name, levels = macro_order)) %>%
    arrange(macro_name) %>%
    select(`Macro-cluster`                = macro_name,
           `Leiden clusters`              = leiden_clusters,
           `N keywords`                   = n_keywords,
           `Total occurrences`            = total_occurrences,
           `Mean pub. year`               = mean_pub_year,
           `Mean citations`               = mean_citations,
           `Top keywords (by occurrence)` = top_keywords)

  write_csv(table7, file.path(TAB, "table_07_macro_clusters.csv"))
  cat("  > Saved: table_07_macro_clusters.csv  [Table 7]\n\n")
}


# =============================================================================
# SUPPLEMENTARY FIGURE S1 — GAM diagnostic plots
# =============================================================================

cat("[7/9] Supplementary Figure S1 — GAM diagnostics...\n")

diag_df <- tibble(
  Year       = docs_per_year$Year,
  observed   = docs_per_year$n,
  fitted     = fitted(modelo_gam),
  resid_dev  = residuals(modelo_gam, type = "deviance"),
  resid_pear = residuals(modelo_gam, type = "pearson"),
  hat_vals   = hatvalues(modelo_gam)
) %>%
  mutate(
    cooks_d = (resid_pear^2 * hat_vals) /
              (modelo_gam$rank * (1 - hat_vals)^2)
  )

cook_thr  <- 4 / nrow(diag_df)
n_obs     <- nrow(diag_df)
qq_df     <- diag_df %>%
  arrange(resid_dev) %>%
  mutate(theoretical = qnorm(ppoints(n_obs)),
         flag        = abs(resid_dev) > 2)

q_obs  <- quantile(qq_df$resid_dev,   c(0.25, 0.75))
q_the  <- quantile(qq_df$theoretical, c(0.25, 0.75))
slope  <- diff(q_obs) / diff(q_the)
intcpt <- q_obs[1] - slope * q_the[1]

pS1a <- ggplot(diag_df, aes(x = fitted, y = resid_dev)) +
  geom_hline(yintercept = 0, color = "grey55", linewidth = 0.5,
             linetype = "dashed") +
  geom_hline(yintercept =  2, color = col_gam, linewidth = 0.4,
             linetype = "dotted", alpha = 0.7) +
  geom_hline(yintercept = -2, color = col_gam, linewidth = 0.4,
             linetype = "dotted", alpha = 0.7) +
  geom_point(color = col_bar, size = 2.5, alpha = 0.8) +
  geom_smooth(method = "loess", se = FALSE,
              color = col_gam, linewidth = 0.9, span = 0.8) +
  geom_text(data = diag_df %>% filter(abs(resid_dev) > 2),
            aes(label = Year), nudge_y = 0.15,
            size = 2.8, color = col_gam) +
  annotate("text",
           x = max(diag_df$fitted) * 0.05,
           y = max(diag_df$resid_dev) * 0.90,
           label = sprintf("φ̂ = %.3f\n%s", phi_hat,
                           ifelse(phi_hat > 1.5,
                                  "Overdispersion detected\nquasi-Poisson recommended",
                                  "Equidispersion assumption met")),
           hjust = 0, vjust = 1, size = 2.8,
           color = col_gam, lineheight = 1.3) +
  labs(title    = "Deviance residuals vs fitted values",
       subtitle = "Dotted lines: |residual| = 2 threshold",
       x = "Fitted values (documents/year)",
       y = "Deviance residuals") +
  theme_minimal(base_size = 10) +
  theme(plot.title       = element_text(face = "bold", size = 10),
        plot.subtitle    = element_text(color = "grey45", size = 8),
        panel.grid.minor = element_blank())

pS1b <- ggplot(qq_df, aes(x = theoretical, y = resid_dev)) +
  geom_abline(intercept = intcpt, slope = slope,
              color = "grey55", linewidth = 0.6, linetype = "dashed") +
  geom_point(aes(color = flag), size = 2.5, alpha = 0.85) +
  geom_text(data = qq_df %>% filter(flag),
            aes(label = Year), nudge_x = 0.08,
            size = 2.8, color = col_gam) +
  scale_color_manual(values = c("FALSE" = col_bar, "TRUE" = col_gam),
                     guide = "none") +
  labs(title    = "Q-Q plot of deviance residuals",
       subtitle = "Orange: |residual| > 2  ·  Dashed: reference line",
       x = "Theoretical quantiles (Normal)",
       y = "Sample quantiles (deviance residuals)") +
  theme_minimal(base_size = 10) +
  theme(plot.title       = element_text(face = "bold", size = 10),
        plot.subtitle    = element_text(color = "grey45", size = 8),
        panel.grid.minor = element_blank())

obs_lim <- range(c(diag_df$observed, diag_df$fitted))

pS1c <- ggplot(diag_df, aes(x = fitted, y = observed)) +
  geom_abline(intercept = 0, slope = 1,
              color = "grey55", linewidth = 0.6, linetype = "dashed") +
  geom_point(color = col_bar, size = 2.5, alpha = 0.8) +
  geom_text_repel(
    data = diag_df %>%
      filter(abs(observed - fitted) > sd(observed - fitted) * 1.5),
    aes(label = Year), size = 2.8, color = col_gam,
    segment.size = 0.3, segment.color = "grey70", max.overlaps = 8
  ) +
  coord_fixed(xlim = obs_lim, ylim = obs_lim) +
  labs(title    = "Observed vs fitted values",
       subtitle = "Dashed line: perfect fit",
       x = "Fitted values (documents/year)",
       y = "Observed values (documents/year)") +
  theme_minimal(base_size = 10) +
  theme(plot.title       = element_text(face = "bold", size = 10),
        plot.subtitle    = element_text(color = "grey45", size = 8),
        panel.grid.minor = element_blank())

pS1d <- ggplot(diag_df, aes(x = Year, y = cooks_d)) +
  geom_hline(yintercept = cook_thr, color = col_gam,
             linewidth = 0.5, linetype = "dashed") +
  geom_segment(aes(xend = Year, yend = 0),
               color = col_bar, linewidth = 0.7, alpha = 0.7) +
  geom_point(aes(color = cooks_d > cook_thr),
             size = 2.5, alpha = 0.85) +
  geom_text_repel(
    data = diag_df %>% filter(cooks_d > cook_thr),
    aes(label = Year), size = 2.8, color = col_gam,
    nudge_y = max(diag_df$cooks_d) * 0.05,
    segment.size = 0.3
  ) +
  annotate("text",
           x = min(diag_df$Year) + 1,
           y = cook_thr * 1.15,
           label = paste0("Threshold: 4/n = ", round(cook_thr, 4)),
           hjust = 0, size = 2.8, color = col_gam) +
  scale_color_manual(values = c("FALSE" = col_bar, "TRUE" = col_gam),
                     guide = "none") +
  scale_x_continuous(breaks = seq(1985, max(diag_df$Year), 5)) +
  labs(title    = "Cook's distance — observation influence",
       subtitle = "Orange: above 4/n influence threshold",
       x = "Year of publication",
       y = "Cook's distance") +
  theme_minimal(base_size = 10) +
  theme(plot.title       = element_text(face = "bold", size = 10),
        plot.subtitle    = element_text(color = "grey45", size = 8),
        panel.grid.minor = element_blank(),
        axis.text.x      = element_text(angle = 45, hjust = 1, size = 8))

pS1 <- (pS1a | pS1b) / (pS1c | pS1d) +
  plot_annotation(
    title    = "Supplementary Figure S1. Diagnostic plots for the GAM Poisson model",
    subtitle = paste0(
      "Model: n ~ s(Year, k = 8), family = Poisson (log link), method = REML  ·  ",
      "N = ", nrow(docs_per_year), " observations  ·  φ̂ = ",
      round(phi_hat, 3)
    ),
    caption = paste0(
      "Top-left: deviance residuals vs fitted values (LOESS smoother). ",
      "Top-right: normal Q-Q plot of deviance residuals. ",
      "Bottom-left: observed vs fitted in response scale. ",
      "Bottom-right: Cook's distance (4/n threshold). ",
      "Orange elements indicate potential outliers or influential observations."
    ),
    theme = theme(
      plot.title    = element_text(face = "bold", size = 12, hjust = 0.5),
      plot.subtitle = element_text(color = "grey45", size = 9,  hjust = 0.5),
      plot.caption  = element_text(color = "grey55", size = 7.5,
                                   hjust = 0.5, margin = margin(t = 8))
    )
  )

ggsave(file.path(FIG, "suppl_figure_S1_gam_diagnostics.png"),
       pS1, width = 14, height = 10, dpi = 300)
cat("  > Saved: suppl_figure_S1_gam_diagnostics.png  [Supplementary Figure S1]\n\n")


# =============================================================================
# FINAL REPORT
# =============================================================================

cat("[9/9] Final report\n\n")
cat("========================================================\n")
cat("  ANALYSIS COMPLETE\n")
cat("========================================================\n")
cat(sprintf("  Output → figures : %s/\n", FIG))
cat(sprintf("  Output → tables  : %s/\n", TAB))
cat("\n  FIGURES GENERATED:\n")
for (f in sort(list.files(FIG))) cat(sprintf("    %s\n", f))
cat("\n  TABLES GENERATED:\n")
for (f in sort(list.files(TAB))) cat(sprintf("    %s\n", f))
cat("\n  NOTE: Figures 1, 7, 9, 10 are generated outside this script:\n")
cat("    Figure 1  → diagram software (flowchart)\n")
cat("    Figure 7  → VOSviewer Network Visualization\n")
cat("    Figure 9  → VOSviewer Overlay Visualization\n")
cat("    Figure 10 → VOSviewer Density Visualization\n")
cat("\n  GAM RESULTS:\n")
cat(sprintf("    edf                = %.4f\n", gam_sum$s.table[1, "edf"]))
cat(sprintf("    Chi-sq             = %.4f\n", gam_sum$s.table[1, "Chi.sq"]))
cat(sprintf("    p-value            = %.6f\n", gam_sum$s.table[1, "p-value"]))
cat(sprintf("    Deviance explained = %.1f%%\n", gam_sum$dev.expl * 100))
cat(sprintf("    R² (adjusted)      = %.4f\n", gam_sum$r.sq))
cat(sprintf("    Overdispersion φ̂  = %.4f\n", phi_hat))
cat(sprintf("    Acceleration point ≈ %d\n", accel_yr))
cat("========================================================\n\n")
