# 04_clean_text.R
# Purpose: Clean and tokenize news articles for sentiment analysis
# Author: Kelvin Chong
# Date: 2025-11-05

# Load libraries ----------------------------------------------------------
library(tidyverse)
library(tidytext)
library(SnowballC)
library(lubridate)
library(arrow)

# Configuration -----------------------------------------------------------

INPUT_FILE <- "data_interim/news_all_consolidated.parquet"
OUTPUT_DIR <- "data_interim"

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Custom stopwords (add airline-specific non-opinion terms)
CUSTOM_STOPWORDS <- c(
  "flight", "airline", "airlines", "aircraft", "airport",
  "passengers", "passenger", "aviation", "flights"
)

# Main Execution ----------------------------------------------------------

cat("========================================\n")
cat("TEXT CLEANING & TOKENIZATION\n")
cat("========================================\n\n")

# Load consolidated news
cat("Loading news data...\n")
news_raw <- read_parquet(INPUT_FILE)
cat(sprintf("  ✓ Loaded %d articles\n\n", nrow(news_raw)))

# Step 1: Basic text cleaning
cat("Step 1: Basic text cleaning...\n")

news_clean <- news_raw %>%
  mutate(
    # Combine headline and description for full text
    text_full = paste(headline, description, sep = " "),
    
    # Clean text
    text_clean = text_full %>%
      str_to_lower() %>%                    # Lowercase
      str_remove_all("https?://\\S+") %>%   # Remove URLs
      str_remove_all("@\\w+") %>%            # Remove mentions
      str_remove_all("#\\w+") %>%            # Remove hashtags
      str_remove_all("[^a-z\\s]") %>%        # Keep only letters and spaces
      str_squish()                           # Remove extra whitespace
  ) %>%
  filter(nchar(text_clean) > 20) %>%        # Remove very short texts
  select(link, headline, source, pub_date, text_clean, scraped_at)

cat(sprintf("  ✓ Cleaned %d articles (removed %d too short)\n\n", 
            nrow(news_clean), 
            nrow(news_raw) - nrow(news_clean)))

# Step 2: Tokenization (unigrams)
cat("Step 2: Tokenizing into words...\n")

tokens_unigram <- news_clean %>%
  unnest_tokens(word, text_clean, token = "words") %>%
  # Remove stopwords
  anti_join(stop_words, by = "word") %>%
  # Remove custom stopwords
  filter(!word %in% CUSTOM_STOPWORDS) %>%
  # Remove numbers
  filter(!str_detect(word, "^[0-9]+$")) %>%
  # Remove very short words
  filter(nchar(word) >= 3)

cat(sprintf("  ✓ Generated %d word tokens from %d articles\n\n", 
            nrow(tokens_unigram),
            n_distinct(tokens_unigram$link)))

# Step 3: Stemming
cat("Step 3: Stemming words...\n")

tokens_stemmed <- tokens_unigram %>%
  mutate(
    word_original = word,
    word_stem = wordStem(word, language = "en")
  )

cat(sprintf("  ✓ Stemmed %d unique words to %d stems\n\n",
            n_distinct(tokens_stemmed$word_original),
            n_distinct(tokens_stemmed$word_stem)))

# Step 4: Bigrams (for context)
cat("Step 4: Creating bigrams...\n")

tokens_bigram <- news_clean %>%
  unnest_tokens(bigram, text_clean, token = "ngrams", n = 2) %>%
  separate(bigram, c("word1", "word2"), sep = " ", remove = FALSE) %>%
  # Remove stopwords from both words
  filter(!word1 %in% stop_words$word,
         !word2 %in% stop_words$word,
         !word1 %in% CUSTOM_STOPWORDS,
         !word2 %in% CUSTOM_STOPWORDS) %>%
  # Remove if either word is too short
  filter(nchar(word1) >= 3, nchar(word2) >= 3) %>%
  select(link, headline, source, pub_date, bigram, scraped_at)

cat(sprintf("  ✓ Generated %d bigrams\n\n", nrow(tokens_bigram)))

# Step 5: Filter by frequency
cat("Step 5: Filtering low-frequency terms...\n")

# Keep words that appear at least 3 times
word_freq <- tokens_stemmed %>%
  count(word_stem, sort = TRUE)

tokens_filtered <- tokens_stemmed %>%
  inner_join(word_freq, by = "word_stem") %>%
  filter(n >= 3) %>%
  select(-n)

cat(sprintf("  ✓ Kept %d tokens (removed rare terms)\n\n", nrow(tokens_filtered)))

# Step 6: Save cleaned data
cat("Step 6: Saving cleaned data...\n")

# Save unigrams
write_parquet(tokens_filtered, file.path(OUTPUT_DIR, "tokens_unigram_clean.parquet"))
write_csv(tokens_filtered, file.path(OUTPUT_DIR, "tokens_unigram_clean.csv"))

# Save bigrams
write_parquet(tokens_bigram, file.path(OUTPUT_DIR, "tokens_bigram_clean.parquet"))
write_csv(tokens_bigram, file.path(OUTPUT_DIR, "tokens_bigram_clean.csv"))

# Save cleaned full texts (for reference)
write_parquet(news_clean, file.path(OUTPUT_DIR, "news_text_clean.parquet"))
write_csv(news_clean, file.path(OUTPUT_DIR, "news_text_clean.csv"))

cat("  ✓ All files saved\n\n")

# Summary Statistics
cat("========================================\n")
cat("SUMMARY STATISTICS\n")
cat("========================================\n\n")

cat("--- Cleaned Articles ---\n")
cat(sprintf("Total articles: %d\n", nrow(news_clean)))
cat(sprintf("Date range: %s to %s\n", 
            min(news_clean$pub_date), 
            max(news_clean$pub_date)))
cat(sprintf("Avg text length: %.0f characters\n\n", 
            mean(nchar(news_clean$text_clean))))

cat("--- Unigram Tokens ---\n")
cat(sprintf("Total tokens: %d\n", nrow(tokens_filtered)))
cat(sprintf("Unique words: %d\n", n_distinct(tokens_filtered$word_original)))
cat(sprintf("Unique stems: %d\n", n_distinct(tokens_filtered$word_stem)))
cat(sprintf("Avg tokens per article: %.1f\n\n",
            nrow(tokens_filtered) / n_distinct(tokens_filtered$link)))

cat("--- Bigrams ---\n")
cat(sprintf("Total bigrams: %d\n", nrow(tokens_bigram)))
cat(sprintf("Unique bigrams: %d\n", n_distinct(tokens_bigram$bigram)))
cat(sprintf("Avg bigrams per article: %.1f\n\n",
            nrow(tokens_bigram) / n_distinct(tokens_bigram$link)))

cat("--- Top 20 Most Frequent Words ---\n")
tokens_filtered %>%
  count(word_original, sort = TRUE) %>%
  head(20) %>%
  print()

cat("\n--- Top 15 Most Frequent Bigrams ---\n")
tokens_bigram %>%
  count(bigram, sort = TRUE) %>%
  head(15) %>%
  print()

cat("\n========================================\n")
cat("✓ Text cleaning complete!\n")
cat("========================================\n")
cat("\nNext step: Run 05_sentiment_analysis.R\n")
