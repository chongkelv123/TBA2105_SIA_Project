# 03_consolidate_all_news_v3.R
# Purpose: Consolidate all collected news from different runs
# Author: Kelvin Chong
# Date: 2025-11-05
# FIXED: Excludes price files, previous consolidated file, handles NA dates

# Load libraries ----------------------------------------------------------
library(tidyverse)
library(arrow)
library(lubridate)

# Configuration -----------------------------------------------------------

DATA_DIR <- "data_interim"

# Main Execution ----------------------------------------------------------

cat("========================================\n")
cat("CONSOLIDATING ALL NEWS COLLECTIONS (v3)\n")
cat("========================================\n\n")

# Find all news parquet files (exclude prices and old consolidated file)
all_files <- list.files(DATA_DIR, pattern = "\\.parquet$", full.names = TRUE)

# CRITICAL: Filter out non-news files
news_files <- all_files %>%
  keep(~!str_detect(.x, "prices_")) %>%           # Exclude price files
  keep(~!str_detect(.x, "news_all_consolidated")) # Exclude old consolidated file

cat(sprintf("Found %d news data files:\n", length(news_files)))
walk(basename(news_files), ~cat(sprintf("  - %s\n", .x)))

if (length(news_files) == 0) {
  stop("❌ No news files found!")
}

# Read and combine all files
cat("\nReading files...\n")
all_data <- map_dfr(news_files, function(file) {
  cat(sprintf("  Reading %s...\n", basename(file)))
  
  df <- read_parquet(file)
  
  # Check if it has news columns
  if (!all(c("headline", "link") %in% colnames(df))) {
    warning(sprintf("  ⚠ Skipping %s - not a news file\n", basename(file)))
    return(tibble())
  }
  
  return(df)
})

cat(sprintf("\nTotal articles before processing: %d\n", nrow(all_data)))

# CRITICAL: Fix date issues
cat("\nProcessing dates...\n")

all_data <- all_data %>%
  mutate(
    # Try to fix NA dates
    pub_date = if_else(
      is.na(pub_date) & !is.na(pub_datetime),
      as.Date(pub_datetime),
      pub_date
    ),
    # If still NA, use scraped_at date
    pub_date = if_else(
      is.na(pub_date) & !is.na(scraped_at),
      as.Date(scraped_at),
      pub_date
    ),
    # If still NA, use today
    pub_date = if_else(
      is.na(pub_date),
      Sys.Date(),
      pub_date
    )
  )

# Check for remaining NA dates
na_dates <- sum(is.na(all_data$pub_date))
if (na_dates > 0) {
  cat(sprintf("  ⚠ Warning: %d articles still have NA dates\n", na_dates))
}

# Deduplicate across all collections
cat("\nDeduplicating...\n")
deduplicated <- all_data %>%
  # Remove exact duplicates
  distinct(headline, link, .keep_all = TRUE) %>%
  # Sort by date and recency
  arrange(desc(pub_date), desc(scraped_at))

cat(sprintf("After deduplication: %d articles\n", nrow(deduplicated)))
cat(sprintf("Removed: %d duplicates (%.1f%%)\n\n", 
            nrow(all_data) - nrow(deduplicated),
            100 * (nrow(all_data) - nrow(deduplicated)) / nrow(all_data)))

# Additional data quality checks
cat("========================================\n")
cat("DATA QUALITY CHECKS\n")
cat("========================================\n\n")

# Check 1: Required columns
required_cols <- c("headline", "link", "source", "pub_date")
missing_cols <- setdiff(required_cols, colnames(deduplicated))
if (length(missing_cols) > 0) {
  warning(sprintf("Missing columns: %s\n", paste(missing_cols, collapse = ", ")))
}

# Check 2: Empty headlines
empty_headlines <- sum(is.na(deduplicated$headline) | deduplicated$headline == "")
if (empty_headlines > 0) {
  cat(sprintf("⚠ Removing %d articles with empty headlines\n", empty_headlines))
  deduplicated <- deduplicated %>% filter(!is.na(headline), headline != "")
}

# Check 3: Duplicate links
duplicate_links <- deduplicated %>%
  group_by(link) %>%
  filter(n() > 1) %>%
  nrow()
if (duplicate_links > 0) {
  cat(sprintf("⚠ Found %d articles with duplicate links - keeping first occurrence\n", duplicate_links))
  deduplicated <- deduplicated %>%
    distinct(link, .keep_all = TRUE)
}

# Check 4: Date range validation
date_range <- range(deduplicated$pub_date, na.rm = TRUE)
if (date_range[1] < Sys.Date() - years(1)) {
  cat(sprintf("⚠ Warning: Earliest date is %s (>1 year ago)\n", date_range[1]))
}
if (date_range[2] > Sys.Date()) {
  cat(sprintf("⚠ Warning: Latest date is %s (future date)\n", date_range[2]))
  # Fix future dates
  deduplicated <- deduplicated %>%
    mutate(pub_date = if_else(pub_date > Sys.Date(), Sys.Date(), pub_date))
}

cat("\n")

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
cat(sprintf("Span: %.0f days (%.1f months)\n\n", date_span, date_span/30))

cat("--- Articles by Source (Top 10) ---\n")
deduplicated %>%
  count(source, sort = TRUE) %>%
  head(10) %>%
  print()

cat("\n--- Articles by Date (Recent) ---\n")
deduplicated %>%
  filter(!is.na(pub_date)) %>%
  count(pub_date, sort = TRUE) %>%
  head(10) %>%
  print()

cat("\n--- Data Completeness ---\n")
cat(sprintf("Articles with headlines: %d (%.1f%%)\n", 
            sum(!is.na(deduplicated$headline)), 
            100 * sum(!is.na(deduplicated$headline)) / nrow(deduplicated)))
cat(sprintf("Articles with descriptions: %d (%.1f%%)\n", 
            sum(!is.na(deduplicated$description) & deduplicated$description != ""), 
            100 * sum(!is.na(deduplicated$description) & deduplicated$description != "") / nrow(deduplicated)))
cat(sprintf("Articles with valid dates: %d (%.1f%%)\n", 
            sum(!is.na(deduplicated$pub_date)), 
            100 * sum(!is.na(deduplicated$pub_date)) / nrow(deduplicated)))

cat("\n========================================\n")
cat("✓ Ready for analysis: %d articles\n", nrow(deduplicated))
cat("========================================\n")