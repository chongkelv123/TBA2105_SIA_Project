# 05_sentiment_analysis.R
# Purpose: Calculate sentiment scores using multiple lexicons
# Author: Kelvin Chong
# Date: 2025-11-05

# Load libraries ----------------------------------------------------------
library(tidyverse)
library(tidytext)
library(lubridate)
library(arrow)

# Configuration -----------------------------------------------------------

INPUT_FILE <- "data_interim/tokens_unigram_clean.parquet"
OUTPUT_DIR <- "data_features"

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Load sentiment lexicons
cat("Loading sentiment lexicons...\n")
bing <- get_sentiments("bing")
afinn <- get_sentiments("afinn")
nrc <- get_sentiments("nrc")
cat("  ✓ Lexicons loaded\n\n")

# Main Execution ----------------------------------------------------------

cat("========================================\n")
cat("SENTIMENT ANALYSIS\n")
cat("========================================\n\n")

# Load cleaned tokens
cat("Loading cleaned tokens...\n")
tokens <- read_parquet(INPUT_FILE)
cat(sprintf("  ✓ Loaded %d tokens from %d articles\n\n", 
            nrow(tokens), 
            n_distinct(tokens$link)))

# Method 1: Bing Lexicon (Positive/Negative Binary)
cat("Method 1: Bing sentiment (binary)...\n")

bing_sentiment <- tokens %>%
  inner_join(bing, by = c("word_original" = "word")) %>%
  count(link, pub_date, source, sentiment) %>%
  pivot_wider(
    names_from = sentiment, 
    values_from = n, 
    values_fill = 0
  ) %>%
  mutate(
    bing_score = (positive - negative) / (positive + negative + 1),
    bing_pos_share = positive / (positive + negative + 1),
    bing_total_words = positive + negative
  )

cat(sprintf("  ✓ Matched %d articles with Bing lexicon\n\n", nrow(bing_sentiment)))

# Method 2: AFINN Lexicon (Valence -5 to +5)
cat("Method 2: AFINN sentiment (valence)...\n")

afinn_sentiment <- tokens %>%
  inner_join(afinn, by = c("word_original" = "word")) %>%
  group_by(link, pub_date, source) %>%
  summarise(
    afinn_score = mean(value, na.rm = TRUE),
    afinn_sum = sum(value, na.rm = TRUE),
    afinn_words = n(),
    .groups = "drop"
  ) %>%
  mutate(
    afinn_score_norm = afinn_score / 5  # Normalize to -1 to +1
  )

cat(sprintf("  ✓ Matched %d articles with AFINN lexicon\n\n", nrow(afinn_sentiment)))

# Method 3: NRC Lexicon (Emotions)
cat("Method 3: NRC sentiment (emotions)...\n")

nrc_sentiment <- tokens %>%
  inner_join(nrc, by = c("word_original" = "word")) %>%
  count(link, pub_date, source, sentiment) %>%
  pivot_wider(
    names_from = sentiment,
    names_prefix = "nrc_",
    values_from = n,
    values_fill = 0
  ) %>%
  mutate(
    # Overall sentiment from NRC
    nrc_score = (nrc_positive - nrc_negative) / (nrc_positive + nrc_negative + 1),
    nrc_emotion_diversity = rowSums(across(starts_with("nrc_")) > 0)
  )

cat(sprintf("  ✓ Matched %d articles with NRC lexicon\n\n", nrow(nrc_sentiment)))

# Combine all sentiment measures
cat("Combining sentiment measures...\n")

sentiment_combined <- tokens %>%
  distinct(link, headline, source, pub_date, scraped_at) %>%
  left_join(bing_sentiment, by = c("link", "pub_date", "source")) %>%
  left_join(afinn_sentiment, by = c("link", "pub_date", "source")) %>%
  left_join(nrc_sentiment, by = c("link", "pub_date", "source")) %>%
  # Fill NAs with neutral (0)
  mutate(across(
    c(bing_score, bing_pos_share, afinn_score, afinn_score_norm, nrc_score),
    ~replace_na(.x, 0)
  ))

cat(sprintf("  ✓ Combined sentiment for %d articles\n\n", nrow(sentiment_combined)))

# Create composite sentiment score (ensemble)
cat("Creating composite sentiment score...\n")

sentiment_final <- sentiment_combined %>%
  mutate(
    # Ensemble: average of normalized scores
    sentiment_composite = (bing_score + afinn_score_norm + nrc_score) / 3,
    
    # Classify sentiment direction
    sentiment_direction = case_when(
      sentiment_composite > 0.1 ~ "positive",
      sentiment_composite < -0.1 ~ "negative",
      TRUE ~ "neutral"
    )
  )

cat("  ✓ Composite score created\n\n")

# Daily aggregation by source
cat("Aggregating sentiment by date...\n")

sentiment_daily <- sentiment_final %>%
  group_by(pub_date) %>%
  summarise(
    # Article counts
    article_count = n(),
    
    # Bing metrics
    sent_bing_mean = mean(bing_score, na.rm = TRUE),
    sent_bing_median = median(bing_score, na.rm = TRUE),
    sent_bing_sd = sd(bing_score, na.rm = TRUE),
    
    # AFINN metrics
    sent_afinn_mean = mean(afinn_score_norm, na.rm = TRUE),
    sent_afinn_median = median(afinn_score_norm, na.rm = TRUE),
    
    # NRC metrics
    sent_nrc_mean = mean(nrc_score, na.rm = TRUE),
    
    # Composite metrics
    sent_composite_mean = mean(sentiment_composite, na.rm = TRUE),
    sent_composite_median = median(sentiment_composite, na.rm = TRUE),
    sent_composite_sd = sd(sentiment_composite, na.rm = TRUE),
    
    # Direction counts
    sent_positive_count = sum(sentiment_direction == "positive"),
    sent_negative_count = sum(sentiment_direction == "negative"),
    sent_neutral_count = sum(sentiment_direction == "neutral"),
    
    # Share of positive
    sent_positive_share = sent_positive_count / article_count,
    
    .groups = "drop"
  ) %>%
  arrange(pub_date)

cat(sprintf("  ✓ Aggregated to %d days\n\n", nrow(sentiment_daily)))

# Save results
cat("Saving results...\n")

# Article-level sentiment
write_parquet(sentiment_final, file.path(OUTPUT_DIR, "sentiment_article_level.parquet"))
write_csv(sentiment_final, file.path(OUTPUT_DIR, "sentiment_article_level.csv"))

# Daily aggregated sentiment
write_parquet(sentiment_daily, file.path(OUTPUT_DIR, "sentiment_daily.parquet"))
write_csv(sentiment_daily, file.path(OUTPUT_DIR, "sentiment_daily.csv"))

cat("  ✓ All files saved\n\n")

# Summary Statistics
cat("========================================\n")
cat("SUMMARY STATISTICS\n")
cat("========================================\n\n")

cat("--- Sentiment Coverage ---\n")
cat(sprintf("Articles with Bing sentiment: %d (%.1f%%)\n",
            sum(!is.na(sentiment_final$bing_score) & sentiment_final$bing_score != 0),
            100 * sum(!is.na(sentiment_final$bing_score) & sentiment_final$bing_score != 0) / nrow(sentiment_final)))
cat(sprintf("Articles with AFINN sentiment: %d (%.1f%%)\n",
            sum(!is.na(sentiment_final$afinn_score)),
            100 * sum(!is.na(sentiment_final$afinn_score)) / nrow(sentiment_final)))
cat(sprintf("Articles with NRC sentiment: %d (%.1f%%)\n\n",
            sum(!is.na(sentiment_final$nrc_score) & sentiment_final$nrc_score != 0),
            100 * sum(!is.na(sentiment_final$nrc_score) & sentiment_final$nrc_score != 0) / nrow(sentiment_final)))

cat("--- Sentiment Distribution ---\n")
sentiment_final %>%
  count(sentiment_direction) %>%
  mutate(percentage = 100 * n / sum(n)) %>%
  print()

cat("\n--- Daily Sentiment Summary ---\n")
cat(sprintf("Days with data: %d\n", nrow(sentiment_daily)))
cat(sprintf("Avg articles per day: %.1f\n", mean(sentiment_daily$article_count)))
cat(sprintf("Avg daily sentiment: %.3f\n", mean(sentiment_daily$sent_composite_mean)))
cat(sprintf("Sentiment volatility (SD): %.3f\n\n", sd(sentiment_daily$sent_composite_mean)))

cat("--- Top 10 Most Positive Articles ---\n")
sentiment_final %>%
  arrange(desc(sentiment_composite)) %>%
  select(pub_date, headline, sentiment_composite) %>%
  head(10) %>%
  print(width = 100)

cat("\n--- Top 10 Most Negative Articles ---\n")
sentiment_final %>%
  arrange(sentiment_composite) %>%
  select(pub_date, headline, sentiment_composite) %>%
  head(10) %>%
  print(width = 100)

cat("\n========================================\n")
cat("✓ Sentiment analysis complete!\n")
cat("========================================\n")
cat("\nNext step: Run 06_feature_engineering.R\n")
