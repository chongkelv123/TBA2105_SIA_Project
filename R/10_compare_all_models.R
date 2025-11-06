# =============================================================================
# TBA2105 Web Mining Project - HELPER SCRIPT
# COMPARE ALL MODEL RESULTS
# =============================================================================
# Purpose: Load and compare results from all three models
# Usage: Run AFTER executing scripts 07, 08, 09
# Author: Kelvin Chong
# Date: November 5, 2025
# =============================================================================

library(tidyverse)
library(glue)

cat("=====================================\n")
cat("MODEL RESULTS COMPARISON\n")
cat("=====================================\n\n")

# =============================================================================
# 1. LOAD ALL SUMMARY FILES
# =============================================================================

cat("📂 Loading results from all models...\n\n")

# Check if results exist
if (!dir.exists("results")) {
  stop("Error: results/ directory not found. Please run modeling scripts first!")
}

# Load summaries
logistic_summary <- read_csv("results/logistic_summary.csv", show_col_types = FALSE)
rf_summary <- read_csv("results/rf_summary.csv", show_col_types = FALSE)
xgb_summary <- read_csv("results/xgb_summary.csv", show_col_types = FALSE)

cat("✓ Loaded all model summaries\n\n")

# =============================================================================
# 2. COMBINE RESULTS
# =============================================================================

cat("📊 Creating comprehensive comparison...\n\n")

# Combine all results
all_results <- bind_rows(
  logistic_summary,
  rf_summary,
  xgb_summary
) %>%
  arrange(type, dataset)

# =============================================================================
# 3. DISPLAY COMPARISON TABLES
# =============================================================================

cat("=====================================\n")
cat("3-CLASS MODEL COMPARISON\n")
cat("=====================================\n\n")

# 3-class results
results_3class <- all_results %>%
  filter(type == "3-Class", dataset == "Test") %>%
  select(model, accuracy, f1_score) %>%
  arrange(desc(f1_score))

cat("TEST SET PERFORMANCE (UP/DOWN/FLAT):\n\n")
print(results_3class, n = Inf)
cat("\n")

# Find best model
best_3class <- results_3class %>% slice(1) %>% pull(model)
best_3class_f1 <- results_3class %>% slice(1) %>% pull(f1_score)

cat(glue("🏆 BEST MODEL: {best_3class}\n"))
cat(glue("   Test F1 Score: {round(best_3class_f1, 4)}\n\n"))

# Show improvement over baseline
baseline_f1 <- results_3class %>% filter(model == "Logistic Regression") %>% pull(f1_score)
improvement_pct <- (best_3class_f1 - baseline_f1) / baseline_f1 * 100

if (best_3class != "Logistic Regression") {
  cat(glue("📈 Improvement over baseline: {round(improvement_pct, 1)}%\n\n"))
}

cat("=====================================\n")
cat("BINARY MODEL COMPARISON\n")
cat("=====================================\n\n")

# Binary results
results_binary <- all_results %>%
  filter(type == "Binary", dataset == "Test") %>%
  select(model, accuracy, f1_score) %>%
  arrange(desc(f1_score))

cat("TEST SET PERFORMANCE (UP vs NOT_UP):\n\n")
print(results_binary, n = Inf)
cat("\n")

# Find best binary model
best_binary <- results_binary %>% slice(1) %>% pull(model)
best_binary_f1 <- results_binary %>% slice(1) %>% pull(f1_score)

cat(glue("🏆 BEST MODEL: {best_binary}\n"))
cat(glue("   Test F1 Score: {round(best_binary_f1, 4)}\n\n"))

# Show improvement
baseline_binary_f1 <- results_binary %>% filter(model == "Logistic Regression") %>% pull(f1_score)
improvement_binary_pct <- (best_binary_f1 - baseline_binary_f1) / baseline_binary_f1 * 100

if (best_binary != "Logistic Regression") {
  cat(glue("📈 Improvement over baseline: {round(improvement_binary_pct, 1)}%\n\n"))
}

# =============================================================================
# 4. TRAINING VS TEST COMPARISON (OVERFITTING CHECK)
# =============================================================================

cat("=====================================\n")
cat("GENERALIZATION ANALYSIS\n")
cat("=====================================\n\n")

cat("Training vs Test Performance (3-Class):\n\n")

overfit_3class <- all_results %>%
  filter(type == "3-Class") %>%
  select(model, dataset, accuracy) %>%
  pivot_wider(names_from = dataset, values_from = accuracy) %>%
  mutate(
    overfitting_gap = Training - Test,
    generalization = case_when(
      overfitting_gap < 0.10 ~ "✓ Good",
      overfitting_gap < 0.15 ~ "⚠ Moderate",
      TRUE ~ "✗ Poor"
    )
  ) %>%
  select(model, Training, Test, overfitting_gap, generalization)

print(overfit_3class, n = Inf)
cat("\n")

# =============================================================================
# 5. FEATURE IMPORTANCE COMPARISON
# =============================================================================

cat("=====================================\n")
cat("FEATURE IMPORTANCE ANALYSIS\n")
cat("=====================================\n\n")

# Check if feature importance files exist
if (file.exists("results/rf_feature_importance_3class.csv") && 
    file.exists("results/xgb_feature_importance_3class.csv")) {
  
  cat("Top 10 Features - Random Forest:\n")
  rf_importance <- read_csv("results/rf_feature_importance_3class.csv", show_col_types = FALSE)
  print(rf_importance %>% select(Variable, Importance_Scaled) %>% head(10), n = 10)
  cat("\n")
  
  cat("Top 10 Features - XGBoost:\n")
  xgb_importance <- read_csv("results/xgb_feature_importance_3class.csv", show_col_types = FALSE)
  print(xgb_importance %>% select(Variable, Importance_Scaled) %>% head(10), n = 10)
  cat("\n")
  
  # Find consensus top features
  top5_rf <- rf_importance %>% slice(1:5) %>% pull(Variable)
  top5_xgb <- xgb_importance %>% slice(1:5) %>% pull(Variable)
  consensus <- intersect(top5_rf, top5_xgb)
  
  if (length(consensus) > 0) {
    cat("🎯 Consensus Top Features (appear in both models' top 5):\n")
    cat(paste("  ", 1:length(consensus), ". ", consensus, collapse = "\n"))
    cat("\n\n")
  }
  
} else {
  cat("⚠ Feature importance files not found. Skipping this section.\n\n")
}

# =============================================================================
# 6. SAVE COMPREHENSIVE COMPARISON
# =============================================================================

cat("💾 Saving comprehensive comparison...\n")

# Save comparison table
write_csv(all_results, "results/model_comparison_all.csv")
write_csv(overfit_3class, "results/overfitting_analysis.csv")

cat("   ✓ Saved: model_comparison_all.csv\n")
cat("   ✓ Saved: overfitting_analysis.csv\n\n")

# =============================================================================
# 7. RECOMMENDATIONS FOR REPORT
# =============================================================================

cat("=====================================\n")
cat("RECOMMENDATIONS FOR YOUR REPORT\n")
cat("=====================================\n\n")

cat("📝 Based on the results:\n\n")

# Recommend best model
cat(glue("1. BEST MODEL FOR PREDICTION:\n"))
cat(glue("   → {best_3class} (Test F1 = {round(best_3class_f1, 3)})\n\n"))

# Check if results are good
if (best_3class_f1 >= 0.48) {
  cat("2. PERFORMANCE ASSESSMENT:\n")
  cat("   → ✅ EXCELLENT - Exceeded target F1 ≥ 0.48!\n\n")
} else if (best_3class_f1 >= 0.45) {
  cat("2. PERFORMANCE ASSESSMENT:\n")
  cat("   → ✅ GOOD - Met realistic target F1 ≥ 0.45\n\n")
} else if (best_3class_f1 >= 0.40) {
  cat("2. PERFORMANCE ASSESSMENT:\n")
  cat("   → ✓ ACCEPTABLE - Reasonable performance given limited sentiment\n\n")
} else {
  cat("2. PERFORMANCE ASSESSMENT:\n")
  cat("   → ⚠ Below target - Consider discussing limitations more\n\n")
}

# Overfitting check
best_overfit <- overfit_3class %>% 
  filter(model == best_3class) %>% 
  pull(overfitting_gap)

cat("3. MODEL GENERALIZATION:\n")
if (best_overfit < 0.10) {
  cat(glue("   → ✅ {best_3class} generalizes well (gap = {round(best_overfit, 3)})\n\n"))
} else if (best_overfit < 0.15) {
  cat(glue("   → ⚠ {best_3class} shows moderate overfitting (gap = {round(best_overfit, 3)})\n"))
  cat("   → Mention in limitations section\n\n")
} else {
  cat(glue("   → ⚠ {best_3class} overfits significantly (gap = {round(best_overfit, 3)})\n"))
  cat("   → Discuss regularization in future work\n\n")
}

# Feature recommendations
cat("4. KEY FEATURES TO DISCUSS:\n")
if (file.exists("results/xgb_feature_importance_3class.csv")) {
  top3 <- xgb_importance %>% slice(1:3) %>% pull(Variable)
  cat(glue("   → {top3[1]} (most important)\n"))
  cat(glue("   → {top3[2]}\n"))
  cat(glue("   → {top3[3]}\n\n"))
} else {
  cat("   → Check feature importance files\n\n")
}

cat("5. WHAT TO EMPHASIZE:\n")
cat("   → Rigorous time-series validation (no lookahead bias)\n")
cat("   → Multiple model comparison (systematic approach)\n")
cat("   → Feature engineering with domain knowledge\n")
cat("   → Transparent about sentiment data limitations\n\n")

cat("6. LIMITATIONS TO MENTION:\n")
cat("   → Limited sentiment coverage (3.8% of observations)\n")
cat("   → Short data collection period (27 days)\n")
cat("   → Single ticker analysis (proof-of-concept)\n")
cat("   → Future work: longer-term news collection\n\n")

# =============================================================================
# 8. FINAL SUMMARY
# =============================================================================

cat("=====================================\n")
cat("SUMMARY STATISTICS\n")
cat("=====================================\n\n")

cat(glue("Models Compared: {n_distinct(all_results$model)}\n"))
cat(glue("Best 3-Class Model: {best_3class}\n"))
cat(glue("Best Binary Model: {best_binary}\n"))
cat(glue("Highest Test F1 (3-class): {round(best_3class_f1, 4)}\n"))
cat(glue("Highest Test F1 (binary): {round(best_binary_f1, 4)}\n\n"))

# Success metrics
success_count <- 0
if (best_3class_f1 >= 0.45) success_count <- success_count + 1
if (best_overfit < 0.15) success_count <- success_count + 1
if (results_3class %>% filter(model == "Logistic Regression") %>% pull(f1_score) >= 0.35) success_count <- success_count + 1

cat(glue("Success Criteria Met: {success_count}/3\n"))
if (success_count == 3) {
  cat("🎉 All success criteria achieved!\n\n")
} else if (success_count >= 2) {
  cat("✅ Most success criteria achieved!\n\n")
} else {
  cat("⚠ Review model performance and data quality\n\n")
}

cat("=====================================\n")
cat("Analysis complete! Results saved to results/ directory.\n")
cat("=====================================\n")
