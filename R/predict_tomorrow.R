# ============================================================================
# SIMPLE DAILY PREDICTION SCRIPT
# ============================================================================
# Purpose: Make tomorrow's stock prediction using trained model
# Usage: source("predict_tomorrow.R")
# Author: Kelvin Chong
# Date: November 5, 2025
# ============================================================================

# Load libraries
suppressPackageStartupMessages({
  library(tidyverse)
  library(tidymodels)
  library(quantmod)
  library(glue)
})

# Resolve function conflicts (use dplyr versions)
filter <- dplyr::filter
lag <- dplyr::lag
first <- dplyr::first
last <- dplyr::last

cat("\n")
cat("=====================================\n")
cat("SIA STOCK PREDICTION FOR TOMORROW\n")
cat("=====================================\n\n")

# ============================================================================
# 1. LOAD MODEL
# ============================================================================

cat("📂 Loading trained model...\n")
logistic_model <- readRDS("results/logistic_model_binary.rds")
cat("   ✓ Model loaded successfully\n\n")

# ============================================================================
# 2. GET LATEST MARKET DATA
# ============================================================================

cat("📊 Downloading latest market data...\n")

# Download data (last 100 days to calculate features)
# Suppress warnings about missing values
suppressWarnings({
  sia <- getSymbols("C6L.SI", auto.assign = FALSE, from = Sys.Date() - 100)
  oil <- getSymbols("BZ=F", auto.assign = FALSE, from = Sys.Date() - 100)
  usd <- getSymbols("DX-Y.NYB", auto.assign = FALSE, from = Sys.Date() - 100)
  vix <- getSymbols("^VIX", auto.assign = FALSE, from = Sys.Date() - 100)
  sti <- getSymbols("^STI", auto.assign = FALSE, from = Sys.Date() - 100)
})

# Clean up any NA values in the middle of series
sia <- na.omit(sia)
oil <- na.omit(oil)
usd <- na.omit(usd)
vix <- na.omit(vix)
sti <- na.omit(sti)

cat("   ✓ Downloaded price data\n\n")

# ============================================================================
# 3. CALCULATE FEATURES
# ============================================================================

cat("🔧 Calculating prediction features...\n")

# Helper function for safe calculations
safe_calc <- function(expr, default = 0) {
  tryCatch(expr, error = function(e) default)
}

# Calculate all 19 features + dummy columns for model compatibility
today_features <- tibble(
  date = as.Date(tail(index(sia), 1)),
  ticker = "C6L.SI",
  
  # Dummy columns (model expects these but doesn't use them for prediction)
  target_3class = factor("FLAT", levels = c("DOWN", "FLAT", "UP")),
  target_binary = factor("NOT_UP", levels = c("NOT_UP", "UP")),
  ret_next = 0,
  
  # Price features
  ret_1d = safe_calc(as.numeric(Delt(Cl(sia), k = 1)[nrow(sia)])),
  ret_2d = safe_calc(as.numeric(Delt(Cl(sia), k = 2)[nrow(sia)])),
  ret_5d = safe_calc(as.numeric(Delt(Cl(sia), k = 5)[nrow(sia)])),
  vol_5d = safe_calc(sd(Delt(Cl(sia))[max(1, nrow(sia)-4):nrow(sia)], na.rm = TRUE)),
  vol_20d = safe_calc(sd(Delt(Cl(sia))[max(1, nrow(sia)-19):nrow(sia)], na.rm = TRUE)),
  
  # Moving averages
  ma_ratio_5_20 = safe_calc(mean(tail(Cl(sia), 5)) / mean(tail(Cl(sia), 20)), 1),
  ma_ratio_20_50 = safe_calc(mean(tail(Cl(sia), 20)) / mean(tail(Cl(sia), 50)), 1),
  
  # Volume
  volume_ratio = safe_calc(as.numeric(tail(Vo(sia), 1)) / mean(tail(Vo(sia), 20)), 1),
  
  # Momentum
  momentum_5d = safe_calc(as.numeric(Cl(sia)[nrow(sia)]) / as.numeric(Cl(sia)[nrow(sia)-5]) - 1),
  momentum_10d = safe_calc(as.numeric(Cl(sia)[nrow(sia)]) / as.numeric(Cl(sia)[nrow(sia)-10]) - 1),
  
  # Macro features
  oil_ret_1d = safe_calc(as.numeric(Delt(Cl(oil), k = 1)[nrow(oil)])),
  oil_ret_5d = safe_calc(as.numeric(Delt(Cl(oil), k = 5)[nrow(oil)])),
  usd_ret_1d = safe_calc(as.numeric(Delt(Cl(usd), k = 1)[nrow(usd)])),
  vix_level = safe_calc(as.numeric(Cl(vix)[nrow(vix)])),
  vix_change_1d = safe_calc(as.numeric(Delt(Cl(vix), k = 1)[nrow(vix)])),
  sti_ret_1d = safe_calc(as.numeric(Delt(Cl(sti), k = 1)[nrow(sti)])),
  
  # Sentiment features (set to neutral - update if you have recent news)
  sent_composite_mean = 0,
  sent_positive_share = 0.5,
  article_count = 0
)

cat("   ✓ Features calculated\n\n")

# ============================================================================
# 4. MAKE PREDICTION
# ============================================================================

cat("🎯 Running prediction model...\n\n")

# Get prediction probabilities
prediction_probs <- predict(logistic_model, today_features, type = "prob")

# Get predicted class
predicted_class <- predict(logistic_model, today_features)

# Combine results
prediction_result <- bind_cols(
  today_features %>% select(date, ticker),
  predicted_class,
  prediction_probs
) %>%
  mutate(
    confidence = pmax(.pred_UP, .pred_NOT_UP) * 100,
    prob_up = .pred_UP * 100,
    prob_not_up = .pred_NOT_UP * 100
  )

# ============================================================================
# 5. DISPLAY RESULTS
# ============================================================================

cat("=====================================\n")
cat("PREDICTION RESULTS\n")
cat("=====================================\n\n")

cat("📅 Last Trading Day: ")
cat(as.character(prediction_result$date))
cat("\n📅 Prediction For: ")
cat(as.character(prediction_result$date + 1))
cat(" (Next trading day)\n")

cat("📊 Ticker: ")
cat(as.character(prediction_result$ticker))
cat("\n")

cat("💰 Last Close: SGD ")
cat(round(as.numeric(tail(Cl(sia), 1)), 3))
cat("\n\n")

cat("--- PREDICTION ---\n")
cat("Direction: ")
cat(as.character(prediction_result$.pred_class))
cat("\n")

cat("Confidence: ")
cat(round(prediction_result$confidence, 1))
cat("%\n\n")

cat("--- PROBABILITIES ---\n")
cat("UP Probability: ")
cat(round(prediction_result$prob_up, 1))
cat("%\n")

cat("NOT_UP Probability: ")
cat(round(prediction_result$prob_not_up, 1))
cat("%\n\n")

# ============================================================================
# 6. TRADING SIGNAL
# ============================================================================

cat("--- TRADING SIGNAL ---\n")

signal <- case_when(
  prediction_result$.pred_UP > 0.70 ~ "STRONG BUY ⬆️⬆️⬆️",
  prediction_result$.pred_UP > 0.60 ~ "MODERATE BUY ⬆️⬆️",
  prediction_result$.pred_UP > 0.55 ~ "WEAK BUY ⬆️",
  prediction_result$.pred_UP >= 0.45 ~ "HOLD ➡️ (uncertain)",
  prediction_result$.pred_NOT_UP > 0.70 ~ "STRONG AVOID/SELL ⬇️⬇️⬇️",
  prediction_result$.pred_NOT_UP > 0.60 ~ "MODERATE AVOID ⬇️⬇️",
  TRUE ~ "WEAK AVOID ⬇️"
)

cat(glue("Signal: {signal}\n\n"))

# Add interpretation
if (prediction_result$.pred_UP > 0.55) {
  cat("💡 Interpretation: Model predicts upward movement.\n")
  cat("   Consider buying if other factors align.\n")
} else if (prediction_result$.pred_NOT_UP > 0.55) {
  cat("💡 Interpretation: Model predicts no upward movement.\n")
  cat("   Consider holding or waiting for better entry.\n")
} else {
  cat("💡 Interpretation: Model is uncertain (close to 50/50).\n")
  cat("   Avoid trading on this signal alone.\n")
}

cat("\n")

# ============================================================================
# 7. FEATURE SNAPSHOT
# ============================================================================

cat("\n--- KEY FEATURES (Top 5) ---\n")
cat("5-day return: ")
cat(round(today_features$ret_5d * 100, 2))
cat("%\n")

cat("20/50-day MA ratio: ")
cat(round(today_features$ma_ratio_20_50, 3))
cat("\n")

cat("Volume ratio: ")
cat(round(today_features$volume_ratio, 2))
cat("x\n")

cat("Oil 5-day return: ")
cat(round(today_features$oil_ret_5d * 100, 2))
cat("%\n")

cat("USD 1-day return: ")
cat(round(today_features$usd_ret_1d * 100, 2))
cat("%\n")

cat("\n=====================================\n\n")

# ============================================================================
# 8. SAVE PREDICTION (OPTIONAL)
# ============================================================================

# Uncomment to save predictions to CSV
# dir.create("predictions", showWarnings = FALSE)
# prediction_result %>%
#   write_csv(glue("predictions/prediction_{Sys.Date()}.csv"))
# cat("✓ Prediction saved to predictions/ folder\n\n")

# ============================================================================
# 9. WARNINGS
# ============================================================================

cat("⚠️  IMPORTANT WARNINGS ⚠️\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
cat("1. This model has 77% precision for NOT_UP\n")
cat("   but only 31% precision for UP.\n")
cat("2. Model trained on only 452 observations.\n")
cat("3. DO NOT use for real trading without:\n")
cat("   • Extended validation (6-12 months)\n")
cat("   • Risk management (stop-loss, position sizing)\n")
cat("   • Other analysis (technical, fundamental)\n")
cat("4. Past performance ≠ future results.\n")
cat("5. Always manage risk appropriately.\n")
cat("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")

cat("✅ Prediction complete!\n\n")

# ============================================================================
# RETURN RESULT (for further use)
# ============================================================================

return(prediction_result)