# 03_consolidate_all_news.R
# Purpose: Consolidate all collected news from different runs
# Author: Kelvin Chong
# Date: 2025-11-02

# Load libraries ----------------------------------------------------------
library(tidyverse)
library(arrow)
library(lubridate)

# Configuration -----------------------------------------------------------

DATA_DIR <- "data_interim"
OUTPUT_FILE <- file.path(DATA_DIR, "news_all_consolidated.parquet")

# Main Execution ----------------------------------------------------------

cat("========================================\n")
cat("CONSOLIDATING ALL NEWS COLLECTIONS\n")
cat("========================================\n\n")

# Find all parquet files
all_files <- list.files(DATA_DIR, pattern = "\\.parquet$", full.names = TRUE)

cat(sprintf("Found %d data files:\n", length(all_files)))
walk(basename(all_files), ~cat(sprintf("  - %s\n", .x)))

if (length(all_files) == 0) {
  stop("No data files found!")
}

# Read and combine all files
cat("\nReading files...\n")
all_data <- map_dfr(all_files, function(file) {
  cat(sprintf("  Reading %s...\n", basename(file)))
  read_parquet(file)
})

cat(sprintf("\nTotal articles before deduplication: %d\n", nrow(all_data)))

# Deduplicate across all collections
deduplicated <- all_data %>%
  distinct(headline, link, .keep_all = TRUE) %>%
  arrange(desc(pub_date), desc(scraped_at))

cat(sprintf("After deduplication: %d articles\n", nrow(deduplicated)))
cat(sprintf("Removed: %d duplicates\n\n", nrow(all_data) - nrow(deduplicated)))

# Save consolidated file (BOTH FORMATS)
parquet_file <- file.path(DATA_DIR, "news_all_consolidated.parquet")
csv_file <- file.path(DATA_DIR, "news_all_consolidated.csv")

write_parquet(deduplicated, parquet_file)
write_csv(deduplicated, csv_file)

cat("========================================\n")
cat("CONSOLIDATION COMPLETE (DUAL FORMAT)\n")
cat("========================================\n")
cat(sprintf("Parquet: %s\n", parquet_file))
cat(sprintf("CSV: %s\n", csv_file))
cat(sprintf("Total unique articles: %d\n\n", nrow(deduplicated)))

# Statistics
cat("--- Date Range ---\n")
cat(sprintf("Earliest: %s\n", min(deduplicated$pub_date, na.rm = TRUE)))
cat(sprintf("Latest: %s\n", max(deduplicated$pub_date, na.rm = TRUE)))
date_span <- as.numeric(difftime(
  max(deduplicated$pub_date, na.rm = TRUE),
  min(deduplicated$pub_date, na.rm = TRUE),
  units = "days"
))
cat(sprintf("Span: %.0f days\n\n", date_span))

cat("--- Articles by Source ---\n")
deduplicated %>%
  count(source, sort = TRUE) %>%
  print()

cat("\n--- Articles by Date ---\n")
deduplicated %>%
  count(pub_date, sort = TRUE) %>%
  head(10) %>%
  print()

cat("\n========================================\n")
cat(sprintf("✓ Ready for analysis: %d articles\n", nrow(deduplicated)))
cat("========================================\n")
