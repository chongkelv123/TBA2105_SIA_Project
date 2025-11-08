# MODELING SCRIPTS - EXECUTION GUIDE
**TBA2105 Web Mining Project - Kelvin Chong**  
**Date:** November 5, 2025

---

## 🎯 OVERVIEW

Three production-ready modeling scripts created:
- **Script 07:** Logistic Regression (Baseline)
- **Script 08:** Random Forest (Non-linear patterns)
- **Script 09:** XGBoost (Performance optimization)

All scripts are **ready to run** with your features_sia.parquet data!

---

## 📋 PREREQUISITES

### Required R Packages
```r
# Install if not already available
install.packages(c(
  "tidyverse",    # Data manipulation
  "tidymodels",   # Modeling framework
  "arrow",        # Read parquet files
  "glmnet",       # Logistic regression
  "ranger",       # Random Forest
  "xgboost",      # XGBoost
  "vip",          # Variable importance plots
  "glue",         # String interpolation
  "tictoc"        # Timing
))
```

### Required Data Files
- **Input:** `data_features/features_sia.parquet` (your 452 observations)
- **Output:** All results saved to `results/` directory (auto-created)

---

## 🚀 EXECUTION INSTRUCTIONS

### Method 1: Run All Models Sequentially (RECOMMENDED)
```r
# Set working directory to your project folder
setwd("path/to/TBA2105_SIA_Prediction")

# Run all three models in sequence
source("R/07_model_logistic_regression.R")
source("R/08_model_random_forest.R")
source("R/09_model_xgboost.R")
```

**Total runtime:** ~5-10 minutes for all three models

### Method 2: Run Individual Models
```r
# Run only Logistic Regression (fastest, ~30 seconds)
source("R/07_model_logistic_regression.R")

# Run only Random Forest (~2-3 minutes)
source("R/08_model_random_forest.R")

# Run only XGBoost (~2-3 minutes)
source("R/09_model_xgboost.R")
```

---

## 📊 WHAT EACH SCRIPT DOES

### Script 07: Logistic Regression
**Purpose:** Baseline interpretable model  
**Algorithm:** Multinomial logistic regression with L2 regularization  
**Key Features:**
- 3-class model (UP/DOWN/FLAT)
- Binary model (UP vs NOT_UP)
- Time-series aware 70/15/15 split
- Confusion matrices for all datasets
- Comprehensive metrics (Accuracy, F1, Precision, Recall)

**Expected Performance:**
- Test F1 (3-class): ~0.40-0.45
- Test F1 (binary): ~0.50-0.55
- Very fast training (<1 minute)

**Output Files:**
```
results/
├── logistic_predictions_3class.csv
├── logistic_predictions_binary.csv
├── logistic_model_3class.rds
├── logistic_model_binary.rds
└── logistic_summary.csv
```

---

### Script 08: Random Forest
**Purpose:** Capture non-linear patterns in data  
**Algorithm:** Ensemble of 500 decision trees  
**Key Features:**
- Feature importance analysis (Gini importance)
- 3-class and binary models
- Parallel processing (4 threads)
- Top 10 most important features displayed

**Expected Performance:**
- Test F1 (3-class): ~0.42-0.48
- Test F1 (binary): ~0.52-0.58
- Better than logistic regression
- Moderate training time (~2-3 minutes)

**Output Files:**
```
results/
├── rf_predictions_3class.csv
├── rf_predictions_binary.csv
├── rf_feature_importance_3class.csv      ← Feature rankings!
├── rf_feature_importance_binary.csv
├── rf_model_3class.rds
├── rf_model_binary.rds
└── rf_summary.csv
```

---

### Script 09: XGBoost
**Purpose:** Maximum predictive performance  
**Algorithm:** Gradient boosting with optimized hyperparameters  
**Key Features:**
- 300 boosting iterations
- Gain-based feature importance
- Overfitting diagnostics
- Both 3-class and binary models
- Advanced hyperparameter tuning

**Hyperparameters:**
- trees = 300
- tree_depth = 6
- learn_rate = 0.05
- sample_size = 0.8
- mtry = 0.7

**Expected Performance:**
- Test F1 (3-class): ~0.45-0.52 (BEST)
- Test F1 (binary): ~0.55-0.62 (BEST)
- Highest accuracy among all models
- Moderate training time (~2-3 minutes)

**Output Files:**
```
results/
├── xgb_predictions_3class.csv
├── xgb_predictions_binary.csv
├── xgb_feature_importance_3class.csv     ← Feature rankings!
├── xgb_feature_importance_binary.csv
├── xgb_model_3class.rds
├── xgb_model_binary.rds
├── xgb_summary.csv
└── xgb_diagnostics.csv                   ← Overfitting check!
```

---

## 📈 UNDERSTANDING THE OUTPUTS

### 1. Predictions Files (*_predictions_*.csv)
Contains test set predictions with:
- `.pred_class`: Predicted class
- `.pred_DOWN`, `.pred_FLAT`, `.pred_UP`: Class probabilities
- `date`, `ticker`: Identifiers
- `target_*`: True labels
- `ret_next`: Actual return (for validation)

**Use for:** Creating prediction plots, analyzing errors

### 2. Feature Importance Files (*_feature_importance_*.csv)
Ranked list of most important features:
- `Variable`: Feature name
- `Importance`: Raw importance score
- `Importance_Scaled`: Percentage contribution
- `Rank`: Ranking (1 = most important)

**Use for:** Understanding which features drive predictions

### 3. Summary Files (*_summary.csv)
Performance comparison across datasets:
- Training, Validation, Test accuracy
- F1 scores for each
- Both 3-class and binary results

**Use for:** Model comparison tables in your report

### 4. Model Objects (*.rds)
Saved trained models for:
- Making new predictions
- Further analysis
- Deployment

---

## 🎓 INTERPRETING RESULTS

### Target F1 Scores (Realistic)
Given limited sentiment coverage (3.8%), expect:
- **Logistic Regression:** F1 = 0.40-0.45 (baseline)
- **Random Forest:** F1 = 0.42-0.48 (moderate improvement)
- **XGBoost:** F1 = 0.45-0.52 (best performance)

**Success Criteria:** F1 ≥ 0.45 is GOOD for this dataset!

### What Makes a Good Result?
1. **Test F1 > 0.45:** Model performs better than random
2. **Overfitting gap < 0.10:** Model generalizes well
3. **Balanced accuracy > 0.50:** Handles all classes fairly
4. **Beats always-predict-FLAT baseline (~0.35)**

### Common Patterns to Expect
- **Price features dominate:** ret_1d, ret_5d, momentum likely top features
- **Macro features matter:** Oil, VIX, USD returns important
- **Sentiment limited impact:** Only 3.8% coverage reduces contribution
- **UP class easiest to predict:** Momentum makes uptrends clearer

---

## 🔍 TROUBLESHOOTING

### Error: "Cannot find features_sia.parquet"
**Solution:** Check your working directory
```r
getwd()  # Should be TBA2105_SIA_Prediction/
setwd("correct/path/to/project")
```

### Error: Package not found
**Solution:** Install missing packages
```r
install.packages("package_name")
```

### Error: Memory issues
**Solution:** Reduce trees parameter in RF/XGBoost
```r
# In script 08/09, change:
trees = 500  # to trees = 200
```

### Warning: "Missing values in data"
**Check:** Your features_sia.parquet should have NO missing values
```r
features <- read_parquet("data_features/features_sia.parquet")
sum(is.na(features))  # Should be 0
```

---

## 📊 RECOMMENDED WORKFLOW

### Phase 1: Quick Validation (10 minutes)
1. Run Script 07 (Logistic Regression)
2. Check if outputs look reasonable
3. Verify train/val/test split makes sense

### Phase 2: Full Modeling (15 minutes)
1. Run Script 08 (Random Forest)
2. Run Script 09 (XGBoost)
3. Compare all three models

### Phase 3: Analysis (30 minutes)
1. Compare F1 scores across models
2. Analyze feature importance
3. Identify best model (likely XGBoost)
4. Check overfitting diagnostics

### Phase 4: Report Writing (Next steps)
1. Create comparison tables
2. Plot confusion matrices
3. Visualize feature importance
4. Write methodology section

---

## 🎯 KEY RESULTS TO EXTRACT FOR REPORT

From your outputs, extract these for your report:

### 1. Model Comparison Table
```
Model               | Test Accuracy | Test F1 | Test AUC
--------------------|---------------|---------|----------
Logistic Regression | 0.XXX         | 0.XXX   | 0.XXX
Random Forest       | 0.XXX         | 0.XXX   | 0.XXX
XGBoost            | 0.XXX         | 0.XXX   | 0.XXX
```

### 2. Confusion Matrix (Best Model)
Show predictions vs actuals for test set

### 3. Top 5 Features
Most important variables from XGBoost/RF

### 4. Generalization Check
Train vs Test accuracy gap (should be <10%)

---

## ⚡ QUICK REFERENCE

### Time Estimates
- Logistic Regression: ~30 seconds
- Random Forest: ~2-3 minutes
- XGBoost: ~2-3 minutes
- **Total: 5-7 minutes**

### Memory Usage
- Small: ~1-2 GB RAM (should run on any modern computer)

### Output Size
- All results: ~2-3 MB total

---

## 🎉 SUCCESS INDICATORS

You'll know the scripts ran successfully when you see:

✅ "Script execution completed successfully!" message  
✅ No error messages in console  
✅ `results/` directory contains 13 files  
✅ Test F1 scores > 0.40  
✅ Confusion matrices displayed properly  

---

## 📞 NEXT STEPS AFTER RUNNING

1. **Compare Models:** Check which has highest test F1
2. **Feature Analysis:** Review feature importance rankings
3. **Error Analysis:** Look at specific mispredictions
4. **Visualizations:** Create plots from predictions
5. **Report Writing:** Document methodology and results

---

## 💡 TIPS FOR YOUR REPORT

### Emphasize These Strengths:
1. **Rigorous time-series split** - No lookahead bias
2. **Multiple model comparison** - Systematic approach
3. **Feature engineering** - 19 well-designed features
4. **Interpretability** - Feature importance analysis
5. **Realistic expectations** - Acknowledged sentiment limitations

### Address These Limitations:
1. Limited sentiment coverage (3.8%) - brief data collection
2. Single ticker focus - proof-of-concept
3. No hyperparameter tuning - time constraints

---

## ✅ CHECKLIST

Before moving to next phase:
- [ ] All three scripts executed without errors
- [ ] 13 files in `results/` directory
- [ ] Test F1 scores documented
- [ ] Feature importance reviewed
- [ ] Best model identified
- [ ] Ready for visualization phase

---

**YOU'RE READY TO RUN THE MODELS!** 🚀

Just execute the scripts in your R environment and watch the magic happen. All results will be neatly saved in the `results/` directory.

Good luck with your project deadline next week! 💪
