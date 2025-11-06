# ⚡ QUICK REFERENCE CARD - START HERE!

**Copy-paste these commands to run everything:**

---

## 🚀 EXECUTE ALL MODELS (5 minutes)

```r
# 1. Install packages (first time only)
install.packages(c("tidyverse", "tidymodels", "arrow", 
                   "glmnet", "ranger", "xgboost", "vip", 
                   "glue", "tictoc"))

# 2. Set working directory
setwd("path/to/TBA2105_SIA_Prediction")  # CHANGE THIS!

# 3. Run all models
source("R/07_model_logistic_regression.R")
source("R/08_model_random_forest.R")
source("R/09_model_xgboost.R")

# 4. Compare results
source("R/10_compare_all_models.R")

# DONE! Check results/ directory for outputs
```

---

## 📊 WHAT YOU GET

**13 Output Files:**
- 6 prediction files (3 models × 2 types)
- 4 feature importance files (RF + XGB)
- 3 summary files (1 per model)
- 2 comparison files (from script 10)

---

## 🎯 SUCCESS METRICS

| Metric | Target | Your Result |
|--------|--------|-------------|
| Test F1 (3-class) | ≥ 0.45 | _____ |
| Test F1 (binary) | ≥ 0.50 | _____ |
| Overfitting Gap | < 0.15 | _____ |
| Best Model | XGBoost expected | _____ |

---

## 📝 FOR YOUR REPORT

**Copy these sections:**

### Methodology:
"Three classification models were trained: Logistic Regression (baseline), Random Forest, and XGBoost. Data was split 70/15/15 (train/val/test) chronologically to prevent lookahead bias."

### Results:
"[Best model] achieved test F1 of [your F1], outperforming the baseline by [X]%."

### Top Features:
1. _____ (most important)
2. _____
3. _____

---

## 🆘 TROUBLESHOOTING

**Error: Package not found**
→ Run: `install.packages("package_name")`

**Error: File not found**
→ Check: `getwd()` - should be project root

**Low F1 scores (<0.40)**
→ Still OK! Emphasize methodology and acknowledge sentiment limitation

---

## ✅ CHECKLIST

- [ ] Scripts downloaded to R/ directory
- [ ] Working directory set correctly
- [ ] All packages installed
- [ ] Script 07 run successfully
- [ ] Script 08 run successfully  
- [ ] Script 09 run successfully
- [ ] Script 10 comparison done
- [ ] Results folder has 13+ files
- [ ] Best model identified
- [ ] Ready for report writing

---

## 📞 FILE GUIDE

**Read First:**
- DELIVERY_SUMMARY.md ← Overall guide
- MODELING_GUIDE.md ← Detailed instructions

**Run First:**
- 07_model_logistic_regression.R
- 08_model_random_forest.R
- 09_model_xgboost.R
- 10_compare_all_models.R

**Reference:**
- MODEL_COMPARISON.md ← Model selection guide

---

## 🎯 EXPECTED RUNTIME

- Logistic Regression: ~30 seconds
- Random Forest: ~2-3 minutes
- XGBoost: ~2-3 minutes
- Comparison: ~10 seconds
- **TOTAL: 5-7 minutes**

---

## 🏆 YOUR NEXT 30 MINUTES

**0:00-0:02** → Install packages (if needed)  
**0:02-0:03** → Set working directory  
**0:03-0:10** → Run all 4 scripts  
**0:10-0:20** → Review results files  
**0:20-0:30** → Note down key metrics  

**THEN:** Start writing your results section!

---

## 💪 YOU'RE READY!

Everything is prepared. Just execute and document!

**GO TIME!** 🚀
