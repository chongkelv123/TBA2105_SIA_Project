# MODEL COMPARISON SUMMARY
**TBA2105 Project - Quick Reference Guide**

---

## 🏆 WHICH MODEL TO USE?

### TL;DR Recommendations:

**For Your Report:**
- **Primary Model:** XGBoost (highest performance)
- **Baseline Model:** Logistic Regression (for comparison)
- **Feature Analysis:** Random Forest or XGBoost (importance rankings)

**For Interpretation:**
- **Easiest:** Logistic Regression (linear relationships)
- **Most Insightful:** Random Forest (feature importance)
- **Best Performance:** XGBoost (highest F1/accuracy)

---

## 📊 MODEL COMPARISON TABLE

| Aspect | Logistic Regression | Random Forest | XGBoost |
|--------|-------------------|---------------|---------|
| **Speed** | ⚡ Fastest (~30s) | 🔄 Medium (~2-3 min) | 🔄 Medium (~2-3 min) |
| **Accuracy** | ⭐ Baseline | ⭐⭐ Good | ⭐⭐⭐ Best |
| **Interpretability** | ⭐⭐⭐ High | ⭐⭐ Medium | ⭐ Lower |
| **Overfitting Risk** | ⭐⭐⭐ Low | ⭐⭐ Medium | ⭐ Higher |
| **Feature Importance** | ❌ No | ✅ Yes (Gini) | ✅ Yes (Gain) |
| **Non-linear Patterns** | ❌ No | ✅ Yes | ✅ Yes |
| **Hyperparameters** | Few | Many | Very Many |
| **Academic Acceptability** | ⭐⭐⭐ High | ⭐⭐⭐ High | ⭐⭐ Good |

---

## 🎯 EXPECTED PERFORMANCE RANGES

### 3-Class Model (UP/DOWN/FLAT)

| Model | Expected Test F1 | Expected Test Accuracy |
|-------|------------------|------------------------|
| Logistic Regression | 0.40 - 0.45 | 0.45 - 0.50 |
| Random Forest | 0.42 - 0.48 | 0.47 - 0.53 |
| XGBoost | 0.45 - 0.52 | 0.50 - 0.57 |

### Binary Model (UP vs NOT_UP)

| Model | Expected Test F1 | Expected Test AUC |
|-------|------------------|-------------------|
| Logistic Regression | 0.50 - 0.55 | 0.58 - 0.65 |
| Random Forest | 0.52 - 0.58 | 0.62 - 0.68 |
| XGBoost | 0.55 - 0.62 | 0.65 - 0.72 |

**Note:** These are realistic ranges given your 3.8% sentiment coverage. Higher values indicate excellent performance!

---

## 🔍 WHEN TO USE EACH MODEL

### Use Logistic Regression When:
- ✅ You need a quick baseline
- ✅ You want easy interpretation (coefficients)
- ✅ You need to explain results to non-technical audience
- ✅ You want to identify linear relationships
- ✅ You're concerned about overfitting

### Use Random Forest When:
- ✅ You want to understand feature importance
- ✅ You need to capture non-linear patterns
- ✅ You want a balance of performance and interpretability
- ✅ You don't want to tune many hyperparameters
- ✅ You need robust predictions with less tuning

### Use XGBoost When:
- ✅ You want maximum predictive performance
- ✅ Your goal is highest possible accuracy/F1
- ✅ You're comfortable with some complexity
- ✅ You want state-of-the-art results
- ✅ You're okay with longer training time

---

## 📈 ALGORITHM DETAILS

### Logistic Regression
```
Type: Linear classification
Loss: Cross-entropy
Regularization: L2 (Ridge), penalty = 0.01
Advantages: Fast, interpretable, stable
Disadvantages: Assumes linear relationships
```

### Random Forest
```
Type: Ensemble (bagging)
Trees: 500 decision trees
Features per split: 6 (sqrt of 19)
Advantages: Handles non-linearity, feature importance
Disadvantages: Can overfit, less interpretable
```

### XGBoost
```
Type: Gradient boosting
Trees: 300 boosting iterations
Learning rate: 0.05
Tree depth: 6
Advantages: Best performance, handles complex patterns
Disadvantages: Many hyperparameters, can overfit
```

---

## 🎓 WHAT TO REPORT IN YOUR PROJECT

### Minimum Requirements (Good Project):
1. **One model** trained and evaluated
2. Confusion matrix
3. Accuracy and F1 scores
4. Train/test comparison

### Strong Project:
1. **Two models** compared (e.g., Logistic + XGBoost)
2. Feature importance analysis
3. Overfitting diagnostics
4. Performance comparison table

### Excellent Project (Recommended):
1. **All three models** compared systematically
2. Feature importance from RF and XGBoost
3. Detailed performance analysis (accuracy, F1, precision, recall)
4. Discussion of why XGBoost performs best
5. Error analysis (which predictions are wrong)
6. Acknowledgment of sentiment limitation

---

## 🏅 FEATURE IMPORTANCE INTERPRETATION

### Expected Top Features:
1. **ret_1d** - Yesterday's return (strongest momentum signal)
2. **ret_5d** - 5-day return (medium-term trend)
3. **momentum_5d** - 5-day momentum indicator
4. **vol_5d** - Recent volatility
5. **vix_level** - Market fear gauge
6. **oil_ret_1d** - Oil price changes (aviation fuel costs)
7. **ma_ratio_5_20** - Moving average crossover

### Why These Matter:
- **Price features dominate:** 10/19 features are price-based
- **Momentum is key:** Stock trends continue in short term
- **Macro signals matter:** Oil, VIX, USD affect airlines
- **Sentiment limited:** Only 3.8% coverage reduces impact

---

## ⚠️ COMMON INTERPRETATION MISTAKES

### DON'T Say:
- ❌ "Model has 90% accuracy" (if train accuracy, not test)
- ❌ "Sentiment is most important" (unlikely with 3.8% coverage)
- ❌ "Model perfectly predicts stock prices" (overfitting claim)
- ❌ "This model can be used for trading" (need more validation)

### DO Say:
- ✅ "XGBoost achieved test F1 of 0.48, outperforming baseline"
- ✅ "Price momentum features were most predictive"
- ✅ "Limited sentiment data (3.8% coverage) reduced its impact"
- ✅ "Model shows proof-of-concept for sentiment-based prediction"
- ✅ "Results suggest predictive value but require more data"

---

## 📊 CONFUSION MATRIX INTERPRETATION

### Example Reading:
```
            Predicted
Actual    DOWN  FLAT  UP
  DOWN      15     3   2   (75% recall for DOWN)
  FLAT       4    12   3   (63% recall for FLAT)
  UP         2     3  18   (78% recall for UP)
```

### What to Report:
1. **Overall accuracy:** (15+12+18)/62 = 72.6%
2. **Best predicted class:** UP (78% recall)
3. **Hardest class:** FLAT (63% recall)
4. **Common mistake:** FLAT confused with UP/DOWN

---

## 🎯 SUCCESS METRICS FOR YOUR GRADE

### Minimum (Pass):
- Test accuracy > 40%
- One model trained properly
- Basic evaluation metrics

### Good (B/B+):
- Test F1 > 0.40
- Two models compared
- Feature importance analyzed
- Proper time-series validation

### Excellent (A/A-):
- Test F1 > 0.45
- All three models compared
- Comprehensive evaluation
- Insightful feature analysis
- Well-written methodology
- Limitations acknowledged

---

## 💡 TIPS FOR REPORT WRITING

### Structure Your Results Section:

1. **Baseline Performance**
   - "Logistic regression achieved test F1 of 0.43..."
   
2. **Improved Models**
   - "Random Forest improved to F1 of 0.46..."
   - "XGBoost achieved best performance: F1 of 0.50..."

3. **Feature Importance**
   - "Analysis revealed price momentum as most predictive..."
   - "Top 5 features: ret_1d, ret_5d, momentum_5d, vix_level, oil_ret_1d"

4. **Model Selection**
   - "XGBoost was selected as final model due to..."

5. **Limitations**
   - "Limited sentiment coverage (3.8%) reduced its predictive impact..."
   - "Future work should collect longer-term news data..."

---

## ⏰ TIME ALLOCATION (Total: 1-2 hours)

- **Running models:** 10 minutes
- **Analyzing results:** 20 minutes
- **Creating comparison tables:** 15 minutes
- **Writing methodology:** 30 minutes
- **Creating visualizations:** 30 minutes
- **Buffer time:** 15 minutes

---

## 🎉 FINAL CHECKLIST

Before considering modeling complete:
- [ ] All three models executed successfully
- [ ] Test F1 scores documented
- [ ] Best model identified (likely XGBoost)
- [ ] Feature importance analyzed
- [ ] Performance comparison table created
- [ ] Overfitting checked (train vs test gap)
- [ ] Results ready for report
- [ ] Limitations acknowledged

---

## 🚀 NEXT STEPS AFTER MODELING

1. **Visualization Phase:**
   - Confusion matrices (heatmaps)
   - Feature importance bar charts
   - Prediction time series plots
   - ROC curves for binary model

2. **Report Writing:**
   - Methodology section
   - Results section with tables
   - Discussion of findings
   - Limitations and future work

3. **Presentation Prep:**
   - Key results slides
   - Model comparison slide
   - Feature importance visualization
   - Conclusions and learnings

---

**REMEMBER:** 
- F1 > 0.45 is EXCELLENT given your data constraints
- Always report TEST metrics, not training
- Acknowledge sentiment limitation transparently
- Emphasize methodology over perfect accuracy

**YOU'VE GOT THIS!** 💪🎓
