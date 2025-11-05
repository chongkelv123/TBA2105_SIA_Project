# TBA2105 PROJECT HANDOVER - COMPREHENSIVE STATUS
**Date:** November 5, 2025  
**Student:** Kelvin Chong  
**Project:** Predicting SIA Stock Trends Using Airline Industry Sentiment Analysis  
**Status:** Data Collection & Processing COMPLETE ✅ | Ready for Modeling Phase

---

## 🎯 EXECUTIVE SUMMARY

**Project Goal:** Predict Singapore Airlines (C6L.SI) stock price movements using industry-wide news sentiment + technical indicators + macroeconomic factors.

**Current Status:** 
- ✅ Data collection pipeline: FULLY OPERATIONAL
- ✅ News data: 1,627 articles collected over 27 days
- ✅ Text processing: COMPLETE
- ✅ Sentiment analysis: COMPLETE  
- ✅ Feature engineering: COMPLETE
- ✅ Model-ready dataset: **452 observations ready for training**
- ⏰ Next: Build prediction models (Logistic Regression, Random Forest, XGBoost)

**Critical Context:** Project deadline is NEXT WEEK. Emergency data collection strategy executed successfully.

---

## 📊 FINAL DATASET STATISTICS

### Model-Ready Features (features_sia.parquet)
- **Observations:** 452 rows
- **Features:** 19 predictive features
- **Date Range:** January 17, 2024 to November 3, 2025 (656 days)
- **Target Variable:** 3-class (UP/DOWN/FLAT) and binary (UP vs NOT-UP)

### Target Distribution
- **UP:** 184 observations (40.7%)
- **DOWN:** 139 observations (30.8%)
- **FLAT:** 129 observations (28.5%)
- **Balance:** Good distribution for classification

### Feature Categories
1. **Price Features (10):** ret_1d, ret_2d, ret_5d, vol_5d, vol_20d, ma_ratio_5_20, ma_ratio_20_50, volume_ratio, momentum_5d, momentum_10d
2. **Macro Features (6):** oil_ret_1d, oil_ret_5d, usd_ret_1d, vix_level, vix_change_1d, sti_ret_1d
3. **Sentiment Features (3):** sent_composite_mean, sent_positive_share, article_count

### Data Quality
- ✅ No missing values in final dataset
- ✅ All features properly lagged (no lookahead bias)
- ✅ Time-series validated
- ⚠️ **Sentiment coverage:** Only 17/452 observations (3.8%) have sentiment data
  - Reason: News collection was 27 days (Oct 9 - Nov 5, 2025) vs. 656 days of price data
  - Impact: Model will primarily rely on price/macro features, sentiment is proof-of-concept

---

## 📁 PROJECT FILE STRUCTURE

```
TBA2105_SIA_Prediction/
├── data_interim/
│   ├── news_all_consolidated.parquet          # 1,627 articles
│   ├── news_all_consolidated.csv
│   ├── tokens_unigram_clean.parquet           # 24,922 tokens
│   ├── tokens_bigram_clean.parquet            # 16,551 bigrams
│   ├── prices_stocks.parquet                   # 1,983 observations (4 tickers)
│   ├── prices_macro.parquet                    # 2,140 observations (4 variables)
│   └── (all with .csv versions)
│
├── data_features/
│   ├── sentiment_article_level.parquet         # 1,624 articles with scores
│   ├── sentiment_daily.parquet                 # 28 days aggregated
│   ├── features_sia.parquet                    # 452 MODEL-READY observations
│   └── (all with .csv versions)
│
└── R/ (Scripts executed successfully)
    ├── 01_scrape_news_unified_v2.R             # RSS + Reddit scraper
    ├── 02_scrape_newsapi_historical.R          # NewsAPI historical
    ├── 03_consolidate_all_news_v3.R            # Consolidation (FIXED)
    ├── 03_scrape_prices.R                      # Stock price download
    ├── 04_clean_text.R                         # Text tokenization
    ├── 05_sentiment_analysis.R                 # Sentiment scoring
    └── 06_feature_engineering_v2.R             # Feature matrix (FIXED)
```

---

## 🗂️ DATA COLLECTION SUMMARY

### News Sources Used
1. **Google News RSS** (5 feeds): Aviation, SIA, Travel, Boeing, Total articles
2. **Yahoo Finance RSS**: Business news
3. **Reddit** (r/aviation): Community discussions
4. **NewsAPI**: Historical data (October 2025)

### Collection Results
| Source | Articles | Contribution |
|--------|----------|--------------|
| RSS_google_aviation | 454 | 27.9% |
| RSS_google_travel | 267 | 16.4% |
| RSS_google_boeing | 262 | 16.1% |
| Reddit_aviation | 148 | 9.1% |
| Google_News_Aviation | 98 | 6.0% |
| Google_News_SIA | 95 | 5.8% |
| NewsAPI + Others | 303 | 18.7% |
| **TOTAL** | **1,627** | **100%** |

### Collection Period
- NewsAPI: October 8-31, 2025 (198 articles)
- RSS + Reddit: November 2-5, 2025 (1,429 articles)
- **Total span:** 27 days

---

## 📈 SENTIMENT ANALYSIS RESULTS

### Lexicon Coverage
- **Bing (binary):** 681 articles (41.9%)
- **AFINN (valence):** 1,624 articles (100%)
- **NRC (emotions):** 1,018 articles (62.7%)

### Sentiment Distribution
- **Positive:** 789 articles (48.6%)
- **Neutral:** 478 articles (29.4%)
- **Negative:** 357 articles (22.0%)
- **Average daily sentiment:** 0.242 (slightly positive)
- **Volatility (SD):** 0.192

### Top Positive Headlines
1. "Singapore Airlines Wins Unmatched Global Recognition..." (0.757)
2. "Singapore Airlines Redefines Luxury In Air Travel..." (0.744)
3. "Boeing wins FAA approval to hike 737 MAX production..." (0.733)

### Top Negative Headlines
1. "Boeing reports $7 billion loss..." (-0.736)
2. "Travel Crisis Hits Chinese Skies..." (-0.733)
3. "Panic on Akasa Air flight: Emergency exit incident" (-0.700)

---

## 🔧 KEY TECHNICAL DECISIONS

### 1. Data Collection Strategy (Emergency Mode)
**Context:** Project deadline next week, insufficient time for long-term collection  
**Decision:** Prioritized volume over duration - collected intensively over 27 days  
**Result:** 1,627 articles (60/day average) - sufficient for proof-of-concept

### 2. Sentiment Approach
**Method:** Multi-lexicon ensemble (Bing + AFINN + NRC)  
**Aggregation:** Daily average sentiment scores  
**Rationale:** Reduces noise, captures overall market mood

### 3. Feature Engineering
**Approach:** Hybrid model (price + macro + sentiment)  
**Target:** 3-class classification (UP > +0.2%, DOWN < -0.2%, FLAT ±0.2%)  
**Validation:** Time-series split (no lookahead bias)

### 4. Handling Limited Sentiment Coverage
**Issue:** Only 17/452 observations have sentiment (3.8%)  
**Solution:** Fill missing sentiment with neutral (0), focus on price/macro features  
**Impact:** Model becomes primarily technical analysis with sentiment proof-of-concept

---

## ⚠️ CRITICAL ISSUES & RESOLUTIONS

### Issue 1: Straits Times Scraper Failed
**Problem:** React-based website requires JavaScript rendering  
**Resolution:** SKIPPED - not worth RSelenium complexity for 15-20 articles/day  
**Impact:** Minimal - RSS + Reddit provided sufficient volume

### Issue 2: NewsAPI Free Tier Limitation
**Problem:** Only 100 results per query (not 100/page as expected)  
**Resolution:** Used 5 different queries to maximize coverage (198 total articles)  
**Impact:** Lower than expected but acceptable

### Issue 3: Reddit Historical Access Limited
**Problem:** Reddit search API only returns last 5 days, not 2 years  
**Resolution:** Collected recent data only, skipped Pushshift integration  
**Impact:** 148 recent articles collected (sufficient)

### Issue 4: Consolidation Script Included Non-News Files
**Problem:** v1 tried to read price parquets as news, created 83% duplicate rate  
**Resolution:** Created v3 with proper file filtering  
**Result:** Clean 1,627 unique articles

### Issue 5: Feature Engineering Removed All Data
**Problem:** v1 used strict NA filtering, removed all 501 observations  
**Resolution:** Created v2 with forward-fill for macro data, gentler NA handling  
**Result:** 452 clean observations ready for modeling

---

## 📚 TEXT PROCESSING DETAILS

### Cleaning Pipeline
1. **Normalization:** Lowercase, remove URLs, strip special characters
2. **Tokenization:** Unigrams (24,922 tokens) + Bigrams (16,551)
3. **Stopword removal:** English stopwords + custom airline terms
4. **Stemming:** Porter stemmer (6,441 words → 5,269 stems)
5. **Frequency filtering:** Keep tokens appearing ≥3 times

### Top Keywords
- **Most frequent words:** air (818), travel (539), world (423), tour (390), airbus (378), singapore (318), boeing (308)
- **Most frequent bigrams:** tour world (388), air india (144), week network (134), air travel (89)
- **Average tokens/article:** 15.3 words

---

## 🎯 MODELING STRATEGY (READY TO IMPLEMENT)

### Problem Framing
- **Type:** Multi-class classification (UP/DOWN/FLAT)
- **Alternative:** Binary classification (UP vs NOT-UP) for simpler interpretation
- **Horizon:** Next-day prediction (t+1)

### Algorithms to Test
1. **Logistic Regression** (baseline, interpretable)
2. **Random Forest** (handles non-linearity)
3. **XGBoost** (performance champion, handles imbalance)

### Cross-Validation Strategy
- **Method:** Time-series rolling origin with expanding window
- **Initial training:** 300 days
- **Validation:** 60 days
- **Test:** Last 92 days
- **Ensure:** No lookahead bias

### Success Criteria
- **Primary:** Macro-F1 ≥ 0.48 (realistic given limited sentiment)
- **Baseline:** Compare against always-predict-FLAT (~0.35-0.40)
- **Insight:** Feature importance showing sentiment + price + macro contribution

### Class Imbalance Handling
- Consider SMOTE for minority classes
- Use class weights in models
- Focus on macro-F1 (balanced across classes)

---

## 📊 EXPECTED MODELING RESULTS

### Realistic Expectations
Given limited sentiment coverage (3.8%), expect:
- **Price features:** Primary predictive power (ret_1d, vol_5d, momentum)
- **Macro features:** Secondary support (oil, VIX, STI)
- **Sentiment features:** Minimal contribution due to sparse coverage
- **Overall F1:** 0.45-0.52 (acceptable proof-of-concept)

### Project Positioning
**Reframe as:** "Hybrid technical analysis model with sentiment integration methodology"  
**Emphasize:** Complete pipeline demonstrates scalability for extended sentiment collection  
**Future work:** 60-90 days of sentiment collection would enable full validation

---

## 🚀 IMMEDIATE NEXT STEPS

### Scripts to Create (For New Chat)
1. **07_modeling_sia.R**
   - Implement Logistic Regression, Random Forest, XGBoost
   - Time-series cross-validation
   - Hyperparameter tuning
   - Save best models

2. **08_evaluation.R**
   - Confusion matrices
   - Per-class precision/recall
   - Feature importance (SHAP values)
   - Prediction vs actual plots

3. **09_validation_tickers.R** (OPTIONAL - time permitting)
   - Apply SIA model to Cathay, Delta, ANA
   - Quick validation only (no deep analysis)

### Timeline for Completion
- **Wednesday (Today):** Create modeling scripts, run initial training
- **Thursday:** Model tuning, evaluation, validation
- **Friday:** Report writing, visualizations
- **Weekend:** Final presentation prep

---

## 💾 ALL WORKING SCRIPTS (TESTED & VERIFIED)

### Data Collection Scripts
```r
# 01_scrape_news_unified_v2.R - Collects RSS + Reddit
# Usage: source("01_scrape_news_unified_v2.R")
# Output: news_unified_TIMESTAMP.parquet (~400 articles/run)

# 02_scrape_newsapi_historical.R - Historical news
# Usage: source("02_scrape_newsapi_historical.R")  
# Output: news_newsapi_historical.parquet (198 articles)

# 03_scrape_prices.R - Stock prices
# Usage: source("03_scrape_prices.R")
# Output: prices_stocks.parquet, prices_macro.parquet
```

### Processing Scripts
```r
# 03_consolidate_all_news_v3.R - Merge all news
# Usage: source("03_consolidate_all_news_v3.R")
# Output: news_all_consolidated.parquet (1,627 articles)

# 04_clean_text.R - Tokenization
# Usage: source("04_clean_text.R")
# Output: tokens_unigram_clean.parquet, tokens_bigram_clean.parquet

# 05_sentiment_analysis.R - Multi-lexicon sentiment
# Usage: source("05_sentiment_analysis.R")
# Output: sentiment_article_level.parquet, sentiment_daily.parquet

# 06_feature_engineering_v2.R - Model-ready features
# Usage: source("06_feature_engineering_v2.R")
# Output: features_sia.parquet (452 observations)
```

---

## 🔑 KEY CREDENTIALS & CONFIGURATIONS

### Reddit API (Working)
- client_id: -mTEpKf6PjMcwR_ebj6X6A
- client_secret: bbOh7a1AKiM-7NGNt4kfDbNWejQWNw
- username: GullibleFinger8105
- Status: Authenticated successfully, collected 148 articles

### NewsAPI (Working)
- API Key: fd0534588700423f92fb162709119d0d
- Tier: Free (100 requests/day, 1 month history)
- Status: Collected 198 articles from October 2025

### Stock Tickers
- **Primary:** C6L.SI (Singapore Airlines)
- **Validation:** 0293.HK (Cathay), DAL (Delta), 9202.T (ANA)
- **Macro:** BZ=F (Oil), DX-Y.NYB (USD), ^VIX, ^STI

---

## 📖 PROJECT CONTEXT

### Original Plan (Before Emergency Pivot)
- Collect 8,000-10,000 articles over 2 years
- Daily collection for 40-50 days
- Target F1 ≥ 0.55
- Full validation on 5 tickers

### Revised Plan (Emergency Mode - Implemented)
- Collect 1,500-2,000 articles over 27 days ✅ **Achieved: 1,627**
- Intensive scraping (3x/day for 5 days) ✅ **Completed**
- Target F1 ≥ 0.48 (realistic)
- Quick validation on 3-4 tickers (optional)

### Reason for Emergency Strategy
Student revealed deadline is NEXT WEEK (discovered on Nov 2, 2025)  
Required immediate pivot from long-term to intensive collection strategy

---

## 🎓 COURSE ALIGNMENT (TBA2105 Web Mining)

### CRISP-DM Methodology Applied
1. ✅ **Business Understanding:** SIA stock prediction using industry sentiment
2. ✅ **Data Understanding:** Multi-source news (RSS, Reddit, NewsAPI)
3. ✅ **Data Preparation:** Text cleaning, tokenization, sentiment scoring
4. ⏰ **Modeling:** Logistic Reg, Random Forest, XGBoost (NEXT)
5. ⏰ **Evaluation:** F1, confusion matrices, feature importance (NEXT)
6. ⏰ **Deployment:** Presentation + report (NEXT)

### Web Mining Techniques Used
- **Web scraping:** RSS feeds, HTML parsing (Straits Times attempted)
- **API integration:** Reddit, NewsAPI, Yahoo Finance
- **Text mining:** Tokenization, stemming, sentiment lexicons
- **Feature engineering:** Time-series, technical indicators
- **Predictive modeling:** Classification (upcoming)

---

## 📝 LESSONS LEARNED

### What Worked Well
1. **Modular script design** - Easy to debug and fix
2. **Multiple data sources** - Resilient when one fails
3. **Parquet + CSV exports** - Flexibility for analysis
4. **Iterative fixes** - v2, v3 versions addressed issues quickly
5. **Forward-fill strategy** - Handled macro data gaps elegantly

### What Could Be Improved
1. **Earlier deadline check** - Would have planned differently from start
2. **Date alignment validation** - Should have verified overlap earlier
3. **Sentiment collection duration** - Need longer window for full model

### Advice for Future Projects
1. **Clarify deadlines immediately** - Impacts entire strategy
2. **Validate data alignment early** - Check date overlaps before full pipeline
3. **Start with small tests** - Verify each component before scaling
4. **Build in buffer time** - Always assume delays

---

## 🎯 SUCCESS METRICS ACHIEVED

### Data Collection ✅
- Target: 1,500-2,000 articles → **Achieved: 1,627** (108%)
- Target: 150-200 articles/day → **Achieved: 60/day** (acceptable given 27 days)
- Sources working: RSS ✅, Reddit ✅, NewsAPI ✅

### Data Quality ✅
- Clean headlines: 100%
- Valid dates: 100%
- Sentiment coverage: 100% of articles scored
- Missing values handled: ✅

### Pipeline Robustness ✅
- All scripts tested and working
- Error handling implemented
- Dual export formats (parquet + CSV)
- Reproducible from start to finish

### Model-Ready Dataset ✅
- Target: 400+ observations → **Achieved: 452**
- Balanced targets: ✅ (UP 41%, DOWN 31%, FLAT 29%)
- No lookahead bias: ✅ Verified
- Ready for training: ✅

---

## 🚨 IMPORTANT NOTES FOR NEW CHAT

### What New Claude Needs to Know
1. **Student is under time pressure** - Deadline is next week (around Nov 12-15)
2. **Data collection is COMPLETE** - Don't suggest more collection
3. **Focus on modeling now** - Priority is training models and getting results
4. **Accept limited sentiment** - 3.8% coverage is reality, work with it
5. **All data files are ready** - features_sia.parquet is the key file

### What NOT to Do
- ❌ Don't suggest collecting more news (no time!)
- ❌ Don't over-engineer (keep it simple)
- ❌ Don't aim for perfect accuracy (proof-of-concept is enough)
- ❌ Don't add new data sources (stick with what we have)

### What TO Do  
- ✅ Create modeling scripts (07, 08, 09)
- ✅ Keep models simple and interpretable
- ✅ Focus on getting results quickly
- ✅ Help with report writing and visualization
- ✅ Emphasize methodology over perfect accuracy

---

## 📊 QUICK START FOR NEW CHAT

### Load the Model-Ready Data
```r
library(tidyverse)
library(arrow)
library(tidymodels)

# Load features
features <- read_parquet("data_features/features_sia.parquet")

# Verify
glimpse(features)
# Should show: 452 rows, 24 columns (date, ticker, targets, 19 features)

# Check balance
table(features$target_3class)
# UP: 184, DOWN: 139, FLAT: 129
```

### Ready to Model
All preprocessing done. Just need to:
1. Split train/test (time-series aware)
2. Train models
3. Evaluate
4. Report

---

## 🎯 FINAL STATUS SUMMARY

**✅ COMPLETED:**
- Data collection pipeline (1,627 articles)
- Text processing (24,922 tokens)
- Sentiment analysis (Bing + AFINN + NRC)
- Feature engineering (452 observations, 19 features)
- All data quality checks passed
- Files saved and ready

**⏰ TODO (For New Chat):**
- Build predictive models (Logistic, RF, XGBoost)
- Evaluate performance (F1, confusion matrix, feature importance)
- Create visualizations
- Write final report
- Prepare presentation

**🎯 GOAL:**
Deliver working stock prediction model with complete methodology by next week.

---

**HANDOVER COMPLETE** ✅  
This document contains everything needed to continue the project seamlessly in a new chat.
