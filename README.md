# 📈 Singapore Airlines Stock Prediction Using Sentiment Analysis

> Predicting SIA stock movements by combining web-mined sentiment with technical indicators and macroeconomic factors. Achieved **0.781 F1 score** (33% better than random baseline).

**Course:** TBA2105 Web Mining | **Institution:** NUS-SCALE | **Date:** November 2025

---

## 🎯 Quick Overview

- **Objective:** Predict next-day Singapore Airlines (C6L.SI) stock direction (UP vs NOT_UP)
- **Data:** 1,627 news articles + 656 days stock prices + macro indicators
- **Best Model:** Logistic Regression (F1=0.781, 66.7% accuracy)
- **Key Finding:** Simple models beat complex ensembles with limited data

---

## 📊 Results

| Model | Test F1 | Accuracy | Overfit Gap |
|-------|---------|----------|-------------|
| **Logistic Regression** 🏆 | **0.781** | **66.7%** | **6%** ✅ |
| Random Forest | 0.695 | 58.0% | 38% ⚠️ |
| XGBoost | 0.591 | 47.8% | 51% ⚠️ |

---

## 🏗️ Project Structure
```
sia-stock-prediction/
├── data/                  # Raw & processed data
├── notebooks/             # R Markdown analysis notebooks
├── src/                   # Source code
│   ├── data_collection/   # Web scraping scripts
│   ├── preprocessing/     # Sentiment & feature engineering
│   ├── models/            # ML models (LR, RF, XGBoost)
│   └── deployment/        # Production prediction system
├── results/               # Model outputs & visualizations
├── docs/                  # Documentation & presentation
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites
```r
# R packages required
install.packages(c("tidyverse", "rvest", "tidytext", "textdata", 
                   "quantmod", "caret", "randomForest", "xgboost"))
```

### Installation
```bash
git clone https://github.com/yourusername/sia-stock-prediction.git
cd sia-stock-prediction
Rscript dependencies.R
```

---

## 📚 Methodology (CRISP-DM)

**1. Business Understanding**
- Binary classification: UP vs NOT_UP
- Success metric: F1 score > 0.5

**2. Data Collection**
- News: 1,627 articles (RSS, Reddit, NewsAPI)
- Stock: 656 days (Yahoo Finance)
- Macro: Oil, USD, VIX, STI

**3. Data Preparation**
- Text: 24,922 tokens, 3 sentiment lexicons
- Features: 19 variables (10 price, 6 macro, 3 sentiment)

**4. Modeling**
- Algorithms: Logistic Regression, Random Forest, XGBoost
- Validation: Time-series split (70/15/15)

**5. Evaluation**
- Winner: Logistic Regression (F1=0.781)
- Key insight: Simple models generalize better

---

## 🎯 Key Features

**Top 5 Drivers:**
1. `oil_ret_5d` (9.8%) - 5-day oil return
2. `volume_ratio` (9.7%) - Trading volume
3. `usd_ret_1d` (9.4%) - USD/SGD return
4. `ma_ratio_20_50` (9.1%) - Moving average ratio
5. `vol_20d` (8.6%) - 20-day volatility

**Importance by Category:**
- Price features: ~60%
- Macro features: ~38%
- Sentiment features: ~2%

---

## 🎯 Production System

**Capabilities:**
- ✅ Automated data download (Yahoo Finance)
- ✅ Real-time feature calculation (19 variables)
- ✅ Probability-based forecasts
- ✅ Risk-aware trading signals (HOLD when uncertain)

**Example Output:**
```
📅 Prediction Date: 2025-11-11
📊 Ticker: C6L.SI (Singapore Airlines)
💰 Last Close: SGD 6.62

--- PREDICTION ---
Direction: NOT_UP
Confidence: 54.5%

--- TRADING SIGNAL ---
Signal: HOLD ➡️ (uncertain - close to 50/50)
```

---

## 🔬 Key Insights

1. **Model Selection Matters:** Simple Logistic Regression beat ensemble methods by 12% F1 with limited data (452 observations)

2. **Problem Formulation Critical:** Binary (F1=0.781) vastly outperformed 3-class (F1=0.257) - 204% improvement

3. **Overfitting Detection:** RF achieved 100% training accuracy but collapsed on test. LR maintained 6% gap only.

4. **Feature Engineering Works:** Price & macro features dominated (98% combined). Sentiment minimal (2%) due to limited coverage.

---

## ⚠️ Limitations

- **Sentiment coverage:** Only 3.8% (17/656 days) - needs 6-12 months collection
- **Single ticker:** SIA only - requires multi-airline validation
- **Distribution shift:** Test period showed different patterns than training
- **UP precision:** Only 31% vs 77% for NOT_UP - use cautiously for buy signals

---

## 🔮 Future Work

**Short-term:**
- Collect 6-12 months of news data
- Test on multiple airline tickers
- Add earnings reports & analyst ratings

**Long-term:**
- Deep learning (BERT, transformers)
- Multi-modal analysis (news + social + fundamentals)
- Intraday prediction

---

## 📄 Documentation

- **[Presentation Slides](docs/presentation/TBA2105_SIA_Stock_Prediction.pdf)** - Final presentation
- **[Project Proposal](docs/project_proposal.pdf)** - Initial scope

---

## ⚠️ Disclaimer

**FOR EDUCATIONAL PURPOSES ONLY.** 

- DO NOT use for real trading without extensive validation (6-12 months minimum)
- Past performance ≠ future results
- Model has 77% NOT_UP precision but only 31% UP precision
- Always manage risk appropriately and consult financial advisors

---

## 🙏 Acknowledgments

**Course:** TBA2105 Web Mining, National University of Singapore - SCALE  
**Data Sources:** Yahoo Finance, Google News, Reddit, NewsAPI  
**Sentiment Lexicons:** Bing, AFINN, NRC

---

## 📧 Contact

**Kelvin Chong**  
GitHub: [@chongkelv123](https://github.com/chongkelv123)  
Email: e0895806@u.nus.edu

**Project Link:** [https://github.com/chongkelv123/sia-stock-prediction](https://github.com/chongkelv123/sia-stock-prediction)

---

## 📌 Citation
```bibtex
@misc{chong2025sia,
  author = {Chong, Kelvin},
  title = {Singapore Airlines Stock Prediction Using Sentiment Analysis},
  year = {2025},
  publisher = {GitHub},
  howpublished = {\url{https://github.com/chongkelv123/sia-stock-prediction}},
  note = {TBA2105 Web Mining Project, NUS-SCALE}
}
```

---

<div align="center">

**⭐ Star this repo if you find it helpful!**

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://www.python.org/)
[![R](https://img.shields.io/badge/R-4.0+-276DC3.svg)](https://www.r-project.org/)

Made with ❤️ for TBA2105 Web Mining | November 2025

</div>