# 06_feature_engineering_v2.R
# Purpose: Combine sentiment + prices + macro into model-ready features
# Author: Kelvin Chong
# Date: 2025-11-05
# FIXED: Handles missing macro data gracefully, uses forward-fill

# Load libraries ----------------------------------------------------------
library(tidyverse)
library(tidyquant)
library(lubridate)
library(arrow)
library(zoo)

# Configuration -----------------------------------------------------------

# Input files
SENTIMENT_FILE <- "data_features/sentiment_daily.parquet"
PRICES_FILE <- "data_interim/prices_stocks.parquet"
MACRO_FILE <- "data_interim/prices_macro.parquet"

OUTPUT_DIR <- "data_features"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Target thresholds for classification
THRESHOLD_UP <- 0.002    # +0.2%
THRESHOLD_DOWN <- -0.002 # -0.2%

# Main Execution ----------------------------------------------------------

cat("========================================\n")
cat("FEATURE ENGINEERING (v2 - FIXED)\n")
cat("========================================\n\n")

# Load data
cat("Loading data...\n")
sentiment <- read_parquet(SENTIMENT_FILE)
prices_raw <- read_parquet(PRICES_FILE)
macro_raw <- read_parquet(MACRO_FILE)

cat(sprintf("  ✓ Sentiment: %d days\n", nrow(sentiment)))
cat(sprintf("  ✓ Prices: %d observations (%d-%d)\n", 
            nrow(prices_raw),
            year(min(prices_raw$date)),
            year(max(prices_raw$date))))
cat(sprintf("  ✓ Macro: %d observations (%d-%d)\n\n", 
            nrow(macro_raw),
            year(min(macro_raw$date)),
            year(max(macro_raw$date))))

# Step 1: Calculate price features for each ticker
cat("Step 1: Calculating price features...\n")

price_features <- prices_raw %>%
  group_by(ticker) %>%
  arrange(date) %>%
  mutate(
    # Returns
    ret_1d = (Adj.Close - lag(Adj.Close)) / lag(Adj.Close),
    ret_2d = (Adj.Close - lag(Adj.Close, 2)) / lag(Adj.Close, 2),
    ret_5d = (Adj.Close - lag(Adj.Close, 5)) / lag(Adj.Close, 5),
    
    # Volatility (rolling SD of returns)
    vol_5d = rollapply(ret_1d, width = 5, FUN = sd, fill = NA, align = "right"),
    vol_20d = rollapply(ret_1d, width = 20, FUN = sd, fill = NA, align = "right"),
    
    # Moving averages
    ma_5 = rollmean(Adj.Close, k = 5, fill = NA, align = "right"),
    ma_20 = rollmean(Adj.Close, k = 20, fill = NA, align = "right"),
    ma_50 = rollmean(Adj.Close, k = 50, fill = NA, align = "right"),
    
    # MA ratios (momentum indicators)
    ma_ratio_5_20 = ma_5 / ma_20,
    ma_ratio_20_50 = ma_20 / ma_50,
    
    # Volume features
    volume_ma_20 = rollmean(Volume, k = 20, fill = NA, align = "right"),
    volume_ratio = Volume / volume_ma_20,
    
    # Price momentum
    momentum_5d = (Adj.Close - lag(Adj.Close, 5)) / lag(Adj.Close, 5),
    momentum_10d = (Adj.Close - lag(Adj.Close, 10)) / lag(Adj.Close, 10),
    
    # Create next-day return (TARGET variable)
    ret_next = lead(ret_1d, 1)
  ) %>%
  ungroup()

cat(sprintf("  ✓ Created features for %d tickers\n\n", n_distinct(price_features$ticker)))

# Step 2: Process macro variables with forward-fill
cat("Step 2: Processing macro variables (with forward-fill)...\n")

# Create a complete date sequence
date_range <- seq(min(prices_raw$date), max(prices_raw$date), by = "day")

macro_features <- macro_raw %>%
  select(date, ticker, Adj.Close) %>%
  pivot_wider(
    names_from = ticker,
    values_from = Adj.Close,
    names_prefix = "macro_"
  ) %>%
  # Create complete date range
  right_join(tibble(date = date_range), by = "date") %>%
  arrange(date) %>%
  # Forward-fill missing values (carry last known value)
  fill(starts_with("macro_"), .direction = "down") %>%
  # Calculate features
  mutate(
    # Oil price features (Brent Crude) - with safety checks
    oil_price = `macro_BZ=F`,
    oil_ret_1d = if_else(!is.na(oil_price) & !is.na(lag(oil_price)),
                         (oil_price - lag(oil_price)) / lag(oil_price), 
                         0),
    oil_ret_5d = if_else(!is.na(oil_price) & !is.na(lag(oil_price, 5)),
                         (oil_price - lag(oil_price, 5)) / lag(oil_price, 5),
                         0),
    
    # USD Index features
    usd_price = `macro_DX-Y.NYB`,
    usd_ret_1d = if_else(!is.na(usd_price) & !is.na(lag(usd_price)),
                         (usd_price - lag(usd_price)) / lag(usd_price),
                         0),
    
    # VIX features (market volatility)
    vix_level = coalesce(`macro_^VIX`, 20),  # Default to 20 if missing
    vix_change_1d = vix_level - lag(vix_level, default = 0),
    
    # Singapore STI features
    sti_price = `macro_^STI`,
    sti_ret_1d = if_else(!is.na(sti_price) & !is.na(lag(sti_price)),
                         (sti_price - lag(sti_price)) / lag(sti_price),
                         0)
  ) %>%
  select(date, oil_ret_1d, oil_ret_5d, usd_ret_1d, vix_level, vix_change_1d, sti_ret_1d)

cat("  ✓ Created macro features with forward-fill\n\n")

# Step 3: Combine everything - Focus on SIA (C6L.SI)
cat("Step 3: Combining features for SIA...\n")

sia_data <- price_features %>%
  filter(ticker == "C6L.SI") %>%
  # Join macro variables (left join to keep all SIA dates)
  left_join(macro_features, by = "date") %>%
  # Join sentiment (left join to keep dates without sentiment)
  left_join(
    sentiment %>% rename(date = pub_date),
    by = "date"
  ) %>%
  # Fill macro NAs with 0 (neutral)
  mutate(across(
    c(oil_ret_1d, oil_ret_5d, usd_ret_1d, vix_change_1d, sti_ret_1d),
    ~replace_na(.x, 0)
  )) %>%
  # Fill sentiment NAs with 0 (neutral)
  mutate(across(
    starts_with("sent_") | starts_with("article_"),
    ~replace_na(.x, 0)
  ))

cat(sprintf("  ✓ Combined data: %d observations\n\n", nrow(sia_data)))

# Step 4: Create target variable (classification)
cat("Step 4: Creating target variable...\n")

sia_features <- sia_data %>%
  mutate(
    # 3-class target
    target_3class = case_when(
      ret_next > THRESHOLD_UP ~ "UP",
      ret_next < THRESHOLD_DOWN ~ "DOWN",
      TRUE ~ "FLAT"
    ),
    
    # Binary target (UP vs NOT-UP)
    target_binary = if_else(ret_next > THRESHOLD_UP, "UP", "NOT_UP")
  ) %>%
  # Remove rows where target is NA (last day, no future return)
  filter(!is.na(ret_next))

cat(sprintf("  ✓ Created targets for %d observations\n\n", nrow(sia_features)))

# Step 5: Handle missing values more carefully
cat("Step 5: Handling missing values...\n")

# Only keep rows after sufficient history for moving averages
sia_features_clean <- sia_features %>%
  filter(
    !is.na(ma_5), !is.na(ma_20), !is.na(ma_50),
    !is.na(vol_5d), !is.na(vol_20d),
    !is.na(ret_1d)
  )

cat(sprintf("  ✓ Clean dataset: %d observations\n", nrow(sia_features_clean)))
cat(sprintf("  Removed %d observations (insufficient history)\n\n",
            nrow(sia_features) - nrow(sia_features_clean)))

# Check if we have any data left
if (nrow(sia_features_clean) == 0) {
  cat("❌ ERROR: No observations remain after filtering!\n")
  cat("This likely means sentiment dates don't overlap with price dates.\n\n")
  
  cat("Sentiment date range: ", as.character(min(sentiment$pub_date)), "to", as.character(max(sentiment$pub_date)), "\n")
  cat("Price date range: ", as.character(min(prices_raw$date)), "to", as.character(max(prices_raw$date)), "\n")
  
  stop("Cannot proceed without data overlap. Check your date ranges!")
}

# Step 6: Create feature matrix for modeling
cat("Step 6: Creating model-ready feature matrix...\n")

model_features <- sia_features_clean %>%
  select(
    # Identifiers
    date, ticker,
    
    # Target variables
    target_3class, target_binary, ret_next,
    
    # Price features (lagged - no lookahead bias)
    ret_1d, ret_2d, ret_5d,
    vol_5d, vol_20d,
    ma_ratio_5_20, ma_ratio_20_50,
    volume_ratio,
    momentum_5d, momentum_10d,
    
    # Macro features
    oil_ret_1d, oil_ret_5d,
    usd_ret_1d,
    vix_level, vix_change_1d,
    sti_ret_1d,
    
    # Sentiment features
    sent_composite_mean, 
    sent_positive_share,
    article_count
  ) %>%
  # Final cleanup: remove any remaining NAs
  drop_na() %>%
  arrange(date)

cat(sprintf("  ✓ Feature matrix ready: %d rows × %d features\n\n",
            nrow(model_features),
            ncol(model_features) - 5))  # Exclude identifiers and targets

# Step 7: Save results
cat("Step 7: Saving feature matrices...\n")

# Save main feature matrix
write_parquet(model_features, file.path(OUTPUT_DIR, "features_sia.parquet"))
write_csv(model_features, file.path(OUTPUT_DIR, "features_sia.csv"))

cat("  ✓ All files saved\n\n")

# Summary Statistics
cat("========================================\n")
cat("SUMMARY STATISTICS\n")
cat("========================================\n\n")

cat("--- Dataset Overview ---\n")
cat(sprintf("Observations: %d\n", nrow(model_features)))
cat(sprintf("Features: %d\n", ncol(model_features) - 5))
cat(sprintf("Date range: %s to %s\n", 
            as.character(min(model_features$date)), 
            as.character(max(model_features$date))))
cat(sprintf("Days: %d\n\n", 
            as.numeric(difftime(max(model_features$date), 
                               min(model_features$date), 
                               units = "days"))))

cat("--- Target Distribution (3-class) ---\n")
model_features %>%
  count(target_3class) %>%
  mutate(percentage = sprintf("%.1f%%", 100 * n / sum(n))) %>%
  print()

cat("\n--- Target Distribution (binary) ---\n")
model_features %>%
  count(target_binary) %>%
  mutate(percentage = sprintf("%.1f%%", 100 * n / sum(n))) %>%
  print()

cat("\n--- Data Quality Checks ---\n")
cat(sprintf("Observations with sentiment: %d (%.1f%%)\n",
            sum(model_features$article_count > 0),
            100 * sum(model_features$article_count > 0) / nrow(model_features)))
cat(sprintf("Avg articles per day: %.1f\n", mean(model_features$article_count)))
cat(sprintf("Avg sentiment: %.3f\n\n", mean(model_features$sent_composite_mean)))

cat("--- Top Features by Absolute Correlation with Target ---\n")
cor_with_target <- model_features %>%
  select(ret_next, where(is.numeric)) %>%
  select(-date, -ticker) %>%
  cor(use = "complete.obs") %>%
  as.data.frame() %>%
  rownames_to_column("feature") %>%
  as_tibble() %>%
  select(feature, correlation = ret_next) %>%
  filter(feature != "ret_next") %>%
  arrange(desc(abs(correlation))) %>%
  head(10)

print(cor_with_target)

cat("\n========================================\n")
cat("✓ Feature engineering complete!\n")
cat("========================================\n")
cat(sprintf("\n🎯 READY FOR MODELING: %d observations\n", nrow(model_features)))
cat("\nNext step: Build models on this data!\n")
