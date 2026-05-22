# =============================================================================
# ETHNOMATHEMATICS BIBLIOMETRIC ANALYSIS
# Reusable script for Scopus CSV exports
#
# Paper: "Ethnomathematics in the World: A Bibliometric Mapping of Methods,
#         Cultural Contexts, Pedagogical Practices, Emerging Trends, and
#         Research Gaps"
# Authors: Rodríguez-Nieto C.A., Castillo-Navarro H., Sudirman S.
#
# HOW TO USE:
#   1. Export your corpus from Scopus as CSV (all fields)
#   2. Set INPUT_FILE below to the path of your CSV
#   3. Set OUTPUT_DIR to your preferred output folder
#   4. Run: source("ethnomathematics_bibliometric_analysis.R")
#
# REQUIREMENTS (install once):
#   install.packages(c("tidyverse","mgcv","ggrepel","scales","patchwork","RColorBrewer"))
# =============================================================================

# --- 0. CONFIGURATION --------------------------------------------------------

INPUT_FILE <- "data_ethno.csv"
OUTPUT_DIR <- "output_figures"

# --- 1. SETUP ----------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
  library(mgcv)
  library(ggrepel)
  library(scales)
  library(patchwork)
  library(RColorBrewer)
})

if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR, recursive = TRUE)

cat("\n========================================================\n")
cat("  BIBLIOMETRIC ANALYSIS — Ethnomathematics (Scopus)\n")
cat("========================================================\n\n")

# --- 2. LOAD & PREPROCESS ----------------------------------------------------

cat("[1/6] Loading and preprocessing data...\n")

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

cat(sprintf("  > After year filter: %d records (%d–%d)\n",
            nrow(df), min(df$Year), max(df$Year)))

# Helper: last comma-segment → country
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
  select(EID, Year, Document_Type, Cited_by,
         countries_list) %>%
  unnest(countries_list) %>%
  rename(country = countries_list) %>%
  filter(!is.na(country), country != "")

# Helper: parse semicolon keywords
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

# Helper: parse semicolon authors
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

cat(sprintf("  > Countries: %d mentions, %d unique\n",
            nrow(country_long), n_distinct(country_long$country)))
cat(sprintf("  > Keywords : %d tokens, %d unique\n",
            nrow(kw_long), n_distinct(kw_long$keyword)))
cat("  > Preprocessing complete.\n\n")

# --- Derived summaries -------------------------------------------------------

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

# Save descriptive tables
summary_stats <- tibble(
  Metric = c("Total documents","Year range","Total citations",
             "Mean citations","Median citations",
             "Unique authors","Unique author keywords","Unique countries"),
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

write_csv(summary_stats, file.path(OUTPUT_DIR, "table_01_summary.csv"))
write_csv(doc_type_tab,  file.path(OUTPUT_DIR, "table_02_doc_types.csv"))
write_csv(top_sources,   file.path(OUTPUT_DIR, "table_03_top_sources.csv"))
write_csv(top_countries, file.path(OUTPUT_DIR, "table_04_top_countries.csv"))
write_csv(top_authors,   file.path(OUTPUT_DIR, "table_05_top_authors.csv"))
write_csv(top_keywords,  file.path(OUTPUT_DIR, "table_06_top_keywords.csv"))

print(summary_stats)
cat("\n")

# =============================================================================
# FIGURE 1 — Annual production + GAM Poisson trend
# =============================================================================

cat("[2/6] GAM Poisson — annual production...\n")

docs_per_year <- df %>% count(Year, name = "n") %>% arrange(Year)

modelo_gam <- gam(
  n ~ s(Year, k = 8),
  data   = docs_per_year,
  family = poisson(link = "log"),
  method = "REML"
)

gam_sum <- summary(modelo_gam)
phi_hat <- sum(residuals(modelo_gam, type = "pearson")^2) / modelo_gam$df.residual

cat("  ── GAM Results ──────────────────────────────\n")
cat(sprintf("  edf               : %.3f\n", gam_sum$s.table[1, "edf"]))
cat(sprintf("  Chi-sq statistic       : %.3f\n", gam_sum$s.table[1, "Chi.sq"]))
cat(sprintf("  p-value           : %.6f\n", gam_sum$s.table[1, "p-value"]))
cat(sprintf("  Deviance expl.    : %.1f%%\n", gam_sum$dev.expl * 100))
cat(sprintf("  R² (adjusted)     : %.3f\n", gam_sum$r.sq))
cat(sprintf("  Overdispersion φ̂ : %.3f %s\n", phi_hat,
            ifelse(phi_hat > 1.5, "[WARNING → check quasi-Poisson]", "[OK]")))
cat("  ─────────────────────────────────────────────\n\n")

gam_stats <- tibble(
  Parameter = c("edf","Chi_sq_statistic","p_value",
                "deviance_explained_pct","r_sq_adjusted","overdispersion_phi"),
  Value     = c(
    round(gam_sum$s.table[1,"edf"],       4),
    round(gam_sum$s.table[1,"Chi.sq"],         4),
    round(gam_sum$s.table[1,"p-value"],   6),
    round(gam_sum$dev.expl * 100,         2),
    round(gam_sum$r.sq,                   4),
    round(phi_hat,                        4)
  )
)
write_csv(gam_stats, file.path(OUTPUT_DIR, "table_07_gam_statistics.csv"))
cat("  > GAM stats saved to table_07_gam_statistics.csv\n")

year_seq <- tibble(Year = seq(min(docs_per_year$Year),
                               max(docs_per_year$Year)))
pred <- predict(modelo_gam, newdata = year_seq, type = "link", se.fit = TRUE)
year_seq <- year_seq %>%
  mutate(fit = exp(pred$fit),
         lwr = exp(pred$fit - 1.96 * pred$se.fit),
         upr = exp(pred$fit + 1.96 * pred$se.fit))

col_bar <- "#2C5F8A"
col_gam <- "#D85A30"

p1 <- ggplot() +
  geom_col(data = docs_per_year, aes(x = Year, y = n),
           fill = col_bar, alpha = 0.65, width = 0.75) +
  geom_ribbon(data = year_seq,
              aes(x = Year, ymin = lwr, ymax = upr),
              fill = col_gam, alpha = 0.15) +
  geom_line(data = year_seq,
            aes(x = Year, y = fit),
            color = col_gam, linewidth = 1.1) +
  annotate("text",
           x     = max(docs_per_year$Year) - 0.5,
           y     = max(docs_per_year$n) * 0.90,
           label = sprintf("GAM Poisson (REML)\nedf = %.2f  ·  p < 0.001\nDev. expl. = %.1f%%",
                           gam_sum$s.table[1,"edf"],
                           gam_sum$dev.expl * 100),
           hjust = 1, size = 3.2, color = col_gam) +
  scale_x_continuous(breaks = seq(1985, max(docs_per_year$Year), 5)) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
  labs(
    title    = "Annual scientific production on ethnomathematics indexed in Scopus",
    subtitle = sprintf("N = %d documents · %d–%d",
                       nrow(df), min(df$Year), max(df$Year)),
    x        = "Year of publication",
    y        = "Number of documents",
    caption  = "Blue bars: observed counts.  Orange line: GAM Poisson fitted trend (REML).  Shaded band: 95% CI."
  ) +
  theme_minimal(base_size = 11) +
  theme(plot.title       = element_text(face = "bold", size = 12),
        plot.subtitle    = element_text(color = "grey45", size = 10),
        plot.caption     = element_text(color = "grey55", size = 8),
        panel.grid.minor = element_blank())

ggsave(file.path(OUTPUT_DIR, "fig1_annual_production_gam.png"),
       p1, width = 11, height = 5.5, dpi = 300)
cat("  > Saved: fig1_annual_production_gam.png\n\n")

# =============================================================================
# FIGURE 2 — Top countries (bar) + document type (donut)
# =============================================================================

cat("[3/6] Country bar + document type donut...\n")

p2a <- top_countries %>%
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

p2b <- ggplot(donut_df, aes(ymax = ymax, ymin = ymin,
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
  theme(plot.title       = element_text(face = "bold", size = 11, hjust = 0.5),
        plot.subtitle    = element_text(color = "grey45", size = 9, hjust = 0.5),
        legend.position  = "none")

p2 <- p2a | p2b
ggsave(file.path(OUTPUT_DIR, "fig2_country_doctype.png"),
       p2, width = 14, height = 6, dpi = 300)
cat("  > Saved: fig2_country_doctype.png\n\n")

# =============================================================================
# FIGURE 3 — Stacked bar: Top countries × document type (sunburst alternative)
# =============================================================================

cat("[4/6] Country × document type stacked bar...\n")

top8_countries <- top_countries %>% slice_head(n = 8) %>% pull(country)

doc_short <- c(
  "Article"          = "Article",
  "Conference paper" = "Conf. paper",
  "Book chapter"     = "Book chapter",
  "Review"           = "Review",
  "Conference review"= "Conf. review",
  "Book"             = "Book",
  "Note"             = "Note",
  "Editorial"        = "Editorial",
  "Short survey"     = "Short survey",
  "Erratum"          = "Other",
  "Unknown"          = "Other"
)

country_doctype <- country_long %>%
  filter(country %in% top8_countries) %>%
  mutate(doc_short = recode(Document_Type, !!!doc_short),
         country   = factor(country, levels = rev(top8_countries))) %>%
  count(country, doc_short, name = "n")

p3 <- ggplot(country_doctype,
             aes(x = n, y = country, fill = doc_short)) +
  geom_col(position = "stack", width = 0.75, color = "white", linewidth = 0.3) +
  geom_text(data = country_doctype %>%
              group_by(country) %>%
              summarise(total = sum(n)),
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
    caption  = "A document can be counted in multiple countries if it has authors from different affiliations."
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title         = element_text(face = "bold", size = 12),
    plot.subtitle      = element_text(color = "grey45", size = 9),
    plot.caption       = element_text(color = "grey55", size = 8),
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    legend.position    = "bottom"
  )

ggsave(file.path(OUTPUT_DIR, "fig3_country_by_doctype_stacked.png"),
       p3, width = 11, height = 6, dpi = 300)
cat("  > Saved: fig3_country_by_doctype_stacked.png\n\n")

# =============================================================================
# FIGURE 4 — Sankey-style: Period × Country × Document type (bump chart)
# =============================================================================

cat("[5/6] Temporal evolution by country (bump chart)...\n")

top10_countries <- top_countries %>% slice_head(n = 10) %>% pull(country)

bump_data <- country_long %>%
  filter(country %in% top10_countries) %>%
  mutate(Period = case_when(
    Year < 2010              ~ "Before\n2010",
    Year >= 2010 & Year < 2015 ~ "2010–\n2014",
    Year >= 2015 & Year < 2020 ~ "2015–\n2019",
    Year >= 2020             ~ "2020–\n2026"
  )) %>%
  count(Period, country, name = "n") %>%
  group_by(Period) %>%
  mutate(rank = rank(-n, ties.method = "first")) %>%
  ungroup() %>%
  mutate(Period = factor(Period,
                         levels = c("Before\n2010","2010–\n2014",
                                    "2015–\n2019","2020–\n2026")))

cols_bump <- colorRampPalette(brewer.pal(10, "Paired"))(10)

p4 <- ggplot(bump_data, aes(x = Period, y = rank,
                              group = country, color = country)) +
  geom_line(linewidth = 1.1, alpha = 0.8) +
  geom_point(aes(size = n), alpha = 0.85) +
  geom_text_repel(
    data = bump_data %>% filter(Period == "2020–\n2026"),
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
    title    = "Country ranking by publication period",
    subtitle = "Top 10 countries — rank by number of document affiliations per period",
    x        = NULL,
    y        = "Rank (1 = most productive)",
    caption  = "Point size proportional to number of documents. Labels show 2020–2026 values."
  ) +
  guides(color = "none") +
  theme_minimal(base_size = 11) +
  theme(
    plot.title       = element_text(face = "bold", size = 12),
    plot.subtitle    = element_text(color = "grey45", size = 9),
    plot.caption     = element_text(color = "grey55", size = 8),
    panel.grid.minor = element_blank()
  )

ggsave(file.path(OUTPUT_DIR, "fig4_country_rank_by_period.png"),
       p4, width = 12, height = 7, dpi = 300)
cat("  > Saved: fig4_country_rank_by_period.png\n\n")

# =============================================================================
# FIGURE 5 — Radar chart: keyword profiles by period (polar bar)
# =============================================================================

cat("[6/6] Keyword profiles by period (polar bar)...\n")

top12_kw <- top_keywords %>% slice_head(n = 12) %>% pull(keyword)

radar_data <- kw_long %>%
  mutate(Period = case_when(
    Year < 2015              ~ "Before 2015",
    Year >= 2015 & Year < 2020 ~ "2015–2019",
    Year >= 2020             ~ "2020–2026"
  )) %>%
  filter(keyword %in% top12_kw) %>%
  count(Period, keyword, name = "n") %>%
  group_by(Period) %>%
  mutate(freq_norm = n / sum(n)) %>%
  ungroup() %>%
  mutate(keyword = str_to_title(keyword),
         Period  = factor(Period,
                          levels = c("Before 2015","2015–2019","2020–2026")))

cols_radar <- c("Before 2015" = "#85B7EB",
                "2015–2019"   = "#1D9E75",
                "2020–2026"   = "#D85A30")

p5 <- ggplot(radar_data, aes(x = keyword, y = freq_norm, fill = Period)) +
  geom_col(position = "dodge", alpha = 0.82,
           width = 0.72, color = "white", linewidth = 0.2) +
  coord_polar(clip = "off") +
  scale_fill_manual(values = cols_radar, name = "Period") +
  scale_y_continuous(labels = percent_format(accuracy = 1),
                     expand = expansion(mult = c(0, 0.15))) +
  labs(
    title    = "Keyword profiles by publication period",
    subtitle = "Top 12 author keywords — relative frequency within each period",
    x        = NULL,
    y        = "Relative frequency",
    caption  = "Relative frequency = keyword count / total keyword tokens in the period."
  ) +
  theme_minimal(base_size = 10) +
  theme(
    plot.title       = element_text(face = "bold", size = 12),
    plot.subtitle    = element_text(color = "grey45", size = 9),
    plot.caption     = element_text(color = "grey55", size = 8),
    axis.text.x      = element_text(size = 8, face = "bold"),
    axis.text.y      = element_text(size = 7, color = "grey50"),
    legend.position  = "bottom",
    panel.grid.major = element_line(color = "grey88", linewidth = 0.4)
  )

ggsave(file.path(OUTPUT_DIR, "fig5_radar_keywords_by_period.png"),
       p5, width = 10, height = 9, dpi = 300)
cat("  > Saved: fig5_radar_keywords_by_period.png\n\n")

# =============================================================================
# FINAL REPORT
# =============================================================================

cat("========================================================\n")
cat("  ANALYSIS COMPLETE\n")
cat("========================================================\n")
cat(sprintf("  Output folder : %s/\n", OUTPUT_DIR))
cat("  Files:\n")
for (f in sort(list.files(OUTPUT_DIR))) cat(sprintf("    %s\n", f))
cat("\n  GAM SUMMARY:\n")
cat(sprintf("    edf            = %.3f\n", gam_sum$s.table[1,"edf"]))
cat(sprintf("    Chi.sq         = %.3f\n", gam_sum$s.table[1,"Chi.sq"]))
cat(sprintf("    p-value        = %.6f\n", gam_sum$s.table[1,"p-value"]))
cat(sprintf("    Dev. explained = %.1f%%\n", gam_sum$dev.expl * 100))
cat(sprintf("    R² (adj)       = %.3f\n", gam_sum$r.sq))
cat(sprintf("    φ̂ (overdispersion) = %.3f\n", phi_hat))
cat("========================================================\n\n")
