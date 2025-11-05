# 06_feature_engineering.R
# Purpose: Combine sentiment + prices + macro into model-ready features
# Author: Kelvin Chong
# Date: 2025-11-05

# Load libraries ----------------------------------------------------------
library(tidyverse)
library(tidyquant)
library(lubridate)
library(arrow)

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
cat("FEATURE ENGINEERING\n")
cat("========================================\n\n")

# Load data
cat("Loading data...\n")
sentiment <- read_parquet(SENTIMENT_FILE)
prices_raw <- read_parquet(PRICES_FILE)
macro_raw <- read_parquet(MACRO_FILE)

cat(sprintf("  ✓ Sentiment: %d days\n", nrow(sentiment)))
cat(sprintf("  ✓ Prices: %d observations\n", nrow(prices_raw)))
cat(sprintf("  ✓ Macro: %d observations\n\n", nrow(macro_raw)))

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
    vol_5d = zoo::rollapply(ret_1d, width = 5, FUN = sd, fill = NA, align = "right"),
    vol_20d = zoo::rollapply(ret_1d, width = 20, FUN = sd, fill = NA, align = "right"),
    
    # Moving averages
    ma_5 = zoo::rollmean(Adj.Close, k = 5, fill = NA, align = "right"),
    ma_20 = zoo::rollmean(Adj.Close, k = 20, fill = NA, align = "right"),
    ma_50 = zoo::rollmean(Adj.Close, k = 50, fill = NA, align = "right"),
    
    # MA ratios (momentum indicators)
    ma_ratio_5_20 = ma_5 / ma_20,
    ma_ratio_20_50 = ma_20 / ma_50,
    
    # Volume features
    volume_ma_20 = zoo::rollmean(Volume, k = 20, fill = NA, align = "right"),
    volume_ratio = Volume / volume_ma_20,
    
    # Price momentum
    momentum_5d = (Adj.Close - lag(Adj.Close, 5)) / lag(Adj.Close, 5),
    momentum_10d = (Adj.Close - lag(Adj.Close, 10)) / lag(Adj.Close, 10),
    
    # Create next-day return (TARGET variable)
    ret_next = lead(ret_1d, 1)
  ) %>%
  ungroup()

cat(sprintf("  ✓ Created features for %d tickers\n\n", n_distinct(price_features$ticker)))

# Step 2: Process macro variables
cat("Step 2: Processing macro variables...\n")

macro_features <- macro_raw %>%
  select(date, ticker, Adj.Close) %>%
  pivot_wider(
    names_from = ticker,
    values_from = Adj.Close,
    names_prefix = "macro_"
  ) %>%
  arrange(date) %>%
  mutate(
    # Oil price features (Brent Crude)
    oil_ret_1d = (`macro_BZ=F` - lag(`macro_BZ=F`)) / lag(`macro_BZ=F`),
    oil_ret_5d = (`macro_BZ=F` - lag(`macro_BZ=F`, 5)) / lag(`macro_BZ=F`, 5),
    oil_ma_20 = zoo::rollmean(`macro_BZ=F`, k = 20, fill = NA, align = "right"),
    
    # USD Index features
    usd_ret_1d = (`macro_DX-Y.NYB` - lag(`macro_DX-Y.NYB`)) / lag(`macro_DX-Y.NYB`),
    usd_ret_5d = (`macro_DX-Y.NYB` - lag(`macro_DX-Y.NYB`, 5)) / lag(`macro_DX-Y.NYB`, 5),
    
    # VIX features (market volatility)
    vix_level = `macro_^VIX`,
    vix_change_1d = `macro_^VIX` - lag(`macro_^VIX`),
    vix_ma_5 = zoo::rollmean(`macro_^VIX`, k = 5, fill = NA, align = "right"),
    
    # Singapore STI features
    sti_ret_1d = (`macro_^STI` - lag(`macro_^STI`)) / lag(`macro_^STI`),
    sti_ret_5d = (`macro_^STI` - lag(`macro_^STI`, 5)) / lag(`macro_^STI`, 5)
  ) %>%
  select(-starts_with("macro_"))  # Remove raw macro values

cat("  ✓ Created macro features\n\n")

# Step 3: Combine everything - Focus on SIA (C6L.SI)
cat("Step 3: Combining features for SIA...\n")

sia_data <- price_features %>%
  filter(ticker == "C6L.SI") %>%
  # Join macro variables
  left_join(macro_features, by = "date") %>%
  # Join sentiment (sentiment is already daily, no need for date matching issues)
  left_join(
    sentiment %>% rename(date = pub_date),
    by = "date"
  )

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

# Step 5: Handle missing values
cat("Step 5: Handling missing values...\n")

# Check missing values
missing_summary <- sia_features %>%
  summarise(across(everything(), ~sum(is.na(.)))) %>%
  pivot_longer(everything(), names_to = "feature", values_to = "missing") %>%
  filter(missing > 0) %>%
  arrange(desc(missing))

if (nrow(missing_summary) > 0) {
  cat("  Features with missing values:\n")
  print(missing_summary, n = 20)
  cat("\n")
}

# Fill sentiment NAs with 0 (neutral)
sia_features <- sia_features %>%
  mutate(across(
    starts_with("sent_") | starts_with("article_"),
    ~replace_na(.x, 0)
  ))

# Remove rows with too many NAs (early period with insufficient history)
sia_features_clean <- sia_features %>%
  # Keep only rows after we have enough history for MA50
  filter(date >= min(date) + days(60)) %>%
  # Drop any remaining rows with NAs in key features
  drop_na(
    ret_1d, vol_5d, vol_20d, 
    ma_5, ma_20, ma_50,
    oil_ret_1d, vix_level, sti_ret_1d
  )

cat(sprintf("  ✓ Clean dataset: %d observations (removed %d with missing values)\n\n",
            nrow(sia_features_clean),
            nrow(sia_features) - nrow(sia_features_clean)))

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
    
    # Macro features (lagged)
    oil_ret_1d, oil_ret_5d,
    usd_ret_1d, usd_ret_5d,
    vix_level, vix_change_1d,
    sti_ret_1d, sti_ret_5d,
    
    # Sentiment features (from previous day's news)
    sent_composite_mean, sent_composite_sd,
    sent_positive_share,
    article_count,
    sent_bing_mean, sent_afinn_mean, sent_nrc_mean
  ) %>%
  arrange(date)

cat(sprintf("  ✓ Feature matrix ready: %d rows × %d features\n\n",
            nrow(model_features),
            ncol(model_features) - 3))  # Exclude date, ticker, target

# Step 7: Save results
cat("Step 7: Saving feature matrices...\n")

# Save main feature matrix
write_parquet(model_features, file.path(OUTPUT_DIR, "features_sia.parquet"))
write_csv(model_features, file.path(OUTPUT_DIR, "features_sia.csv"))

# Save full SIA data (for validation tickers later)
write_parquet(sia_features_clean, file.path(OUTPUT_DIR, "sia_full_data.parquet"))

cat("  ✓ All files saved\n\n")

# Summary Statistics
cat("========================================\n")
cat("SUMMARY STATISTICS\n")
cat("========================================\n\n")

cat("--- Dataset Overview ---\n")
cat(sprintf("Observations: %d\n", nrow(model_features)))
cat(sprintf("Features: %d\n", ncol(model_features) - 3))
cat(sprintf("Date range: %s to %s\n", min(model_features$date), max(model_features$date)))
cat(sprintf("Days: %d\n\n", as.numeric(difftime(max(model_features$date), min(model_features$date), units = "days"))))

cat("--- Target Distribution (3-class) ---\n")
model_features %>%
  count(target_3class) %>%
  mutate(percentage = 100 * n / sum(n)) %>%
  print()

cat("\n--- Target Distribution (binary) ---\n")
model_features %>%
  count(target_binary) %>%
  mutate(percentage = 100 * n / sum(n)) %>%
  print()

cat("\n--- Feature Correlations with Target ---\n")
cor_with_target <- model_features %>%
  select(ret_next, where(is.numeric)) %>%
  select(-date) %>%
  cor(use = "complete.obs") %>%
  as.data.frame() %>%
  rownames_to_column("feature") %>%
  select(feature, ret_next) %>%
  arrange(desc(abs(ret_next))) %>%
  filter(feature != "ret_next") %>%
  head(15)

print(cor_with_target)

cat("\n========================================\n")
cat("✓ Feature engineering complete!\n")
cat("========================================\n")
cat("\nNext step: Run 07_modeling_sia.R\n")
cat("\nReady for time-series modeling!\n")
