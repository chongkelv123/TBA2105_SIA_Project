# =============================================================================
# TBA2105 Web Mining Project - Script 08
# RANDOM FOREST MODEL
# =============================================================================
# Purpose: Train Random Forest for SIA stock prediction with feature importance
# Input: data_features/features_sia.parquet
# Output: Model results, predictions, feature importance, evaluation metrics
# Author: Kelvin Chong
# Date: November 5, 2025
# =============================================================================

# Load libraries
library(tidyverse)
library(tidymodels)
library(arrow)
library(ranger)  # Fast random forest implementation
library(vip)     # Variable importance plots
library(glue)
library(tictoc)

# Set random seed for reproducibility
set.seed(42)

cat("=====================================\n")
cat("RANDOM FOREST MODEL\n")
cat("=====================================\n\n")

# =============================================================================
# 1. LOAD DATA
# =============================================================================

cat("📂 Loading model-ready features...\n")
features <- read_parquet("data_features/features_sia.parquet")

cat(glue("   ✓ Loaded {nrow(features)} observations\n"))
cat(glue("   ✓ Date range: {min(features$date)} to {max(features$date)}\n"))
cat(glue("   ✓ Features: {ncol(features) - 4} predictive variables\n\n"))

# =============================================================================
# 2. DATA PREPARATION
# =============================================================================

cat("🔧 Preparing data for modeling...\n")

# Select features for modeling
model_data <- features %>%
  select(
    date, ticker,
    # Target variables
    target_3class, target_binary, ret_next,
    # Price features (10)
    ret_1d, ret_2d, ret_5d, vol_5d, vol_20d,
    ma_ratio_5_20, ma_ratio_20_50, volume_ratio,
    momentum_5d, momentum_10d,
    # Macro features (6)
    oil_ret_1d, oil_ret_5d, usd_ret_1d,
    vix_level, vix_change_1d, sti_ret_1d,
    # Sentiment features (3)
    sent_composite_mean, sent_positive_share, article_count
  ) %>%
  # Convert target to factor for classification
  mutate(
    target_3class = factor(target_3class, levels = c("DOWN", "FLAT", "UP")),
    target_binary = factor(target_binary, levels = c("NOT_UP", "UP"))
  ) %>%
  # Remove any remaining NAs
  drop_na()

cat(glue("   ✓ Final dataset: {nrow(model_data)} observations\n"))
cat(glue("   ✓ Features ready: {ncol(model_data) - 5} variables\n\n"))

# =============================================================================
# 3. TIME-SERIES SPLIT
# =============================================================================

cat("📊 Creating time-series train/validation/test split...\n")

# Sort by date
model_data <- model_data %>% arrange(date)

# Calculate split points
n_total <- nrow(model_data)
n_train <- floor(n_total * 0.70)
n_val <- floor(n_total * 0.15)
n_test <- n_total - n_train - n_val

# Create splits
train_data <- model_data %>% slice(1:n_train)
val_data <- model_data %>% slice((n_train + 1):(n_train + n_val))
test_data <- model_data %>% slice((n_train + n_val + 1):n_total)

cat(glue("   ✓ Training set: {nrow(train_data)} obs ({min(train_data$date)} to {max(train_data$date)})\n"))
cat(glue("   ✓ Validation set: {nrow(val_data)} obs ({min(val_data$date)} to {max(val_data$date)})\n"))
cat(glue("   ✓ Test set: {nrow(test_data)} obs ({min(test_data$date)} to {max(test_data$date)})\n\n"))

# Check target distribution
cat("   Target distribution:\n")
cat("   Training:\n")
print(table(train_data$target_3class))
cat("   Validation:\n")
print(table(val_data$target_3class))
cat("   Test:\n")
print(table(test_data$target_3class))
cat("\n")

# =============================================================================
# 4. MODEL SPECIFICATION - 3-CLASS RANDOM FOREST
# =============================================================================

cat("🌲 Training 3-class Random Forest model...\n")
cat("   (This may take a few minutes...)\n")
tic()

# Create recipe
rf_recipe <- recipe(target_3class ~ ., data = train_data) %>%
  # Remove non-predictive columns
  update_role(date, new_role = "ID") %>%
  update_role(ticker, new_role = "ID") %>%
  update_role(target_binary, new_role = "ID") %>%
  update_role(ret_next, new_role = "ID") %>%
  # Remove zero-variance features
  step_zv(all_predictors())

# Model specification
rf_spec <- rand_forest(
  mtry = 6,           # Number of variables at each split (sqrt(19) ≈ 4-6)
  trees = 500,        # Number of trees
  min_n = 10          # Minimum observations per leaf
) %>%
  set_engine("ranger", 
             importance = "impurity",  # Calculate feature importance
             num.threads = 4,          # Parallel processing
             seed = 42) %>%
  set_mode("classification")

# Create workflow
rf_workflow <- workflow() %>%
  add_recipe(rf_recipe) %>%
  add_model(rf_spec)

# Train the model
rf_fit <- rf_workflow %>%
  fit(data = train_data)

toc()
cat("   ✓ Model trained successfully!\n\n")

# =============================================================================
# 5. FEATURE IMPORTANCE - 3-CLASS MODEL
# =============================================================================

cat("📊 Extracting feature importance...\n")

# Extract feature importance
feature_importance_3class <- rf_fit %>%
  extract_fit_engine() %>%
  vip::vi() %>%
  arrange(desc(Importance)) %>%
  mutate(
    Importance_Scaled = Importance / sum(Importance) * 100,
    Rank = row_number()
  )

cat("\nTop 10 Most Important Features (3-Class Model):\n")
print(feature_importance_3class %>% head(10), n = 10)
cat("\n")

# =============================================================================
# 6. PREDICTIONS - 3-CLASS MODEL
# =============================================================================

cat("🎯 Generating predictions...\n")

# Predict on all datasets
train_pred_3class <- predict(rf_fit, train_data) %>%
  bind_cols(predict(rf_fit, train_data, type = "prob")) %>%
  bind_cols(train_data %>% select(date, ticker, target_3class, ret_next))

val_pred_3class <- predict(rf_fit, val_data) %>%
  bind_cols(predict(rf_fit, val_data, type = "prob")) %>%
  bind_cols(val_data %>% select(date, ticker, target_3class, ret_next))

test_pred_3class <- predict(rf_fit, test_data) %>%
  bind_cols(predict(rf_fit, test_data, type = "prob")) %>%
  bind_cols(test_data %>% select(date, ticker, target_3class, ret_next))

cat("   ✓ Predictions generated for all datasets\n\n")

# =============================================================================
# 7. EVALUATION METRICS - 3-CLASS MODEL
# =============================================================================

cat("📈 Evaluating 3-class model performance...\n\n")

# Function to calculate comprehensive metrics
calc_metrics_3class <- function(predictions, dataset_name) {
  cat(glue("--- {dataset_name} Set ---\n"))
  
  # Confusion matrix
  cm <- conf_mat(predictions, truth = target_3class, estimate = .pred_class)
  cat("Confusion Matrix:\n")
  print(cm)
  cat("\n")
  
  # Calculate metrics
  metrics <- metric_set(accuracy, bal_accuracy, kap)
  overall_metrics <- predictions %>%
    metrics(truth = target_3class, estimate = .pred_class)
  
  # Class-wise F1 scores
  f1_scores <- predictions %>%
    f_meas(truth = target_3class, estimate = .pred_class, estimator = "macro")
  
  # Precision and Recall
  precision <- predictions %>%
    precision(truth = target_3class, estimate = .pred_class, estimator = "macro")
  
  recall <- predictions %>%
    recall(truth = target_3class, estimate = .pred_class, estimator = "macro")
  
  cat("Overall Metrics:\n")
  print(overall_metrics)
  cat("\nF1 Score (Macro):\n")
  print(f1_scores)
  cat("\nPrecision (Macro):\n")
  print(precision)
  cat("\nRecall (Macro):\n")
  print(recall)
  cat("\n")
  
  return(list(
    confusion_matrix = cm,
    metrics = overall_metrics,
    f1 = f1_scores,
    precision = precision,
    recall = recall
  ))
}

# Evaluate on all datasets
train_metrics_3class <- calc_metrics_3class(train_pred_3class, "TRAINING")
val_metrics_3class <- calc_metrics_3class(val_pred_3class, "VALIDATION")
test_metrics_3class <- calc_metrics_3class(test_pred_3class, "TEST")

# =============================================================================
# 8. BINARY MODEL (UP vs NOT_UP)
# =============================================================================

cat("\n🌲 Training Binary Random Forest (UP vs NOT_UP)...\n")

# Binary recipe
binary_recipe <- recipe(target_binary ~ ., data = train_data) %>%
  update_role(date, new_role = "ID") %>%
  update_role(ticker, new_role = "ID") %>%
  update_role(target_3class, new_role = "ID") %>%
  update_role(ret_next, new_role = "ID") %>%
  step_zv(all_predictors())

# Binary model specification
binary_spec <- rand_forest(
  mtry = 6,
  trees = 500,
  min_n = 10
) %>%
  set_engine("ranger",
             importance = "impurity",
             num.threads = 4,
             seed = 42) %>%
  set_mode("classification")

# Binary workflow
binary_workflow <- workflow() %>%
  add_recipe(binary_recipe) %>%
  add_model(binary_spec)

# Train binary model
binary_fit <- binary_workflow %>%
  fit(data = train_data)

cat("   ✓ Binary model trained!\n\n")

# Feature importance - binary
cat("📊 Extracting feature importance (Binary model)...\n")
feature_importance_binary <- binary_fit %>%
  extract_fit_engine() %>%
  vip::vi() %>%
  arrange(desc(Importance)) %>%
  mutate(
    Importance_Scaled = Importance / sum(Importance) * 100,
    Rank = row_number()
  )

cat("\nTop 10 Most Important Features (Binary Model):\n")
print(feature_importance_binary %>% head(10), n = 10)
cat("\n")

# Predictions
train_pred_binary <- predict(binary_fit, train_data) %>%
  bind_cols(predict(binary_fit, train_data, type = "prob")) %>%
  bind_cols(train_data %>% select(date, ticker, target_binary, ret_next))

val_pred_binary <- predict(binary_fit, val_data) %>%
  bind_cols(predict(binary_fit, val_data, type = "prob")) %>%
  bind_cols(val_data %>% select(date, ticker, target_binary, ret_next))

test_pred_binary <- predict(binary_fit, test_data) %>%
  bind_cols(predict(binary_fit, test_data, type = "prob")) %>%
  bind_cols(test_data %>% select(date, ticker, target_binary, ret_next))

# Binary evaluation
cat("📈 Evaluating Binary model performance...\n\n")

calc_metrics_binary <- function(predictions, dataset_name) {
  cat(glue("--- {dataset_name} Set (Binary) ---\n"))
  
  cm <- conf_mat(predictions, truth = target_binary, estimate = .pred_class)
  cat("Confusion Matrix:\n")
  print(cm)
  cat("\n")
  
  # Calculate metrics separately to avoid namespace conflicts
  acc <- predictions %>% accuracy(truth = target_binary, estimate = .pred_class)
  bal_acc <- predictions %>% bal_accuracy(truth = target_binary, estimate = .pred_class)
  sensitivity <- predictions %>% sens(truth = target_binary, estimate = .pred_class)
  specificity <- predictions %>% yardstick::spec(truth = target_binary, estimate = .pred_class)
  f1 <- predictions %>% f_meas(truth = target_binary, estimate = .pred_class)
  auc <- predictions %>% roc_auc(truth = target_binary, .pred_UP)
  
  all_metrics <- bind_rows(acc, bal_acc, sensitivity, specificity, f1, auc)
  
  cat("Metrics:\n")
  print(all_metrics)
  cat("\n")
  
  return(list(confusion_matrix = cm, metrics = all_metrics))
}

train_metrics_binary <- calc_metrics_binary(train_pred_binary, "TRAINING")
val_metrics_binary <- calc_metrics_binary(val_pred_binary, "VALIDATION")
test_metrics_binary <- calc_metrics_binary(test_pred_binary, "TEST")

# =============================================================================
# 9. SAVE RESULTS
# =============================================================================

cat("💾 Saving model results...\n")

# Create output directory
dir.create("results", showWarnings = FALSE)

# Save predictions
write_csv(test_pred_3class, "results/rf_predictions_3class.csv")
write_csv(test_pred_binary, "results/rf_predictions_binary.csv")

# Save feature importance
write_csv(feature_importance_3class, "results/rf_feature_importance_3class.csv")
write_csv(feature_importance_binary, "results/rf_feature_importance_binary.csv")

# Save model objects
saveRDS(rf_fit, "results/rf_model_3class.rds")
saveRDS(binary_fit, "results/rf_model_binary.rds")

# Create summary report
summary_report <- tibble(
  model = "Random Forest",
  dataset = rep(c("Training", "Validation", "Test"), 2),
  type = c(rep("3-Class", 3), rep("Binary", 3)),
  accuracy = c(
    train_metrics_3class$metrics %>% filter(.metric == "accuracy") %>% pull(.estimate),
    val_metrics_3class$metrics %>% filter(.metric == "accuracy") %>% pull(.estimate),
    test_metrics_3class$metrics %>% filter(.metric == "accuracy") %>% pull(.estimate),
    train_metrics_binary$metrics %>% filter(.metric == "accuracy") %>% pull(.estimate),
    val_metrics_binary$metrics %>% filter(.metric == "accuracy") %>% pull(.estimate),
    test_metrics_binary$metrics %>% filter(.metric == "accuracy") %>% pull(.estimate)
  ),
  f1_score = c(
    train_metrics_3class$f1 %>% pull(.estimate),
    val_metrics_3class$f1 %>% pull(.estimate),
    test_metrics_3class$f1 %>% pull(.estimate),
    train_metrics_binary$metrics %>% filter(.metric == "f_meas") %>% pull(.estimate),
    val_metrics_binary$metrics %>% filter(.metric == "f_meas") %>% pull(.estimate),
    test_metrics_binary$metrics %>% filter(.metric == "f_meas") %>% pull(.estimate)
  )
)

write_csv(summary_report, "results/rf_summary.csv")

cat("   ✓ Saved predictions: rf_predictions_3class.csv\n")
cat("   ✓ Saved predictions: rf_predictions_binary.csv\n")
cat("   ✓ Saved feature importance: rf_feature_importance_3class.csv\n")
cat("   ✓ Saved feature importance: rf_feature_importance_binary.csv\n")
cat("   ✓ Saved models: rf_model_3class.rds, rf_model_binary.rds\n")
cat("   ✓ Saved summary: rf_summary.csv\n\n")

# =============================================================================
# 10. FINAL SUMMARY
# =============================================================================

cat("=====================================\n")
cat("RANDOM FOREST - FINAL RESULTS\n")
cat("=====================================\n\n")

cat("3-CLASS MODEL (UP/DOWN/FLAT):\n")
cat(glue("  Test Accuracy: {round(test_metrics_3class$metrics %>% filter(.metric == 'accuracy') %>% pull(.estimate), 4)}\n"))
cat(glue("  Test F1 (Macro): {round(test_metrics_3class$f1 %>% pull(.estimate), 4)}\n"))
cat(glue("  Test Balanced Accuracy: {round(test_metrics_3class$metrics %>% filter(.metric == 'bal_accuracy') %>% pull(.estimate), 4)}\n\n"))

cat("BINARY MODEL (UP vs NOT_UP):\n")
cat(glue("  Test Accuracy: {round(test_metrics_binary$metrics %>% filter(.metric == 'accuracy') %>% pull(.estimate), 4)}\n"))
cat(glue("  Test F1: {round(test_metrics_binary$metrics %>% filter(.metric == 'f_meas') %>% pull(.estimate), 4)}\n"))
cat(glue("  Test AUC-ROC: {round(test_metrics_binary$metrics %>% filter(.metric == 'roc_auc') %>% pull(.estimate), 4)}\n\n"))

cat("TOP 5 MOST IMPORTANT FEATURES (3-Class):\n")
print(feature_importance_3class %>% 
        select(Variable, Importance_Scaled) %>% 
        head(5), n = 5)
cat("\n")

cat("✅ Random Forest modeling complete!\n")
cat("📁 All results saved to results/ directory\n\n")

cat("=====================================\n")
cat("Script execution completed successfully!\n")
cat("=====================================\n")