# ============================================================================
# TBA2105 Web Mining Project - Word Cloud Generation
# Purpose: Visualize cleaned text corpus for presentation
# Student: Kelvin Chong
# Date: November 2025
# ============================================================================

# Load required libraries
library(arrow)        # For reading parquet files
library(dplyr)        # For data manipulation
library(wordcloud)    # For word cloud generation
library(RColorBrewer) # For color palettes
library(tidyr)        # For data reshaping

# ============================================================================
# 1. LOAD TOKEN DATA
# ============================================================================

cat("Loading token data...\n")

# Load the cleaned unigram tokens
tokens <- read_parquet("data_interim/tokens_unigram_clean.parquet")

cat("✓ Loaded", nrow(tokens), "token observations\n")
cat("✓ Unique tokens:", n_distinct(tokens$word), "\n\n")

# ============================================================================
# 2. PREPARE DATA FOR WORD CLOUD
# ============================================================================

cat("Preparing word cloud data...\n")

# Aggregate token frequencies across all articles
# Using 'word' column (cleaned tokens) for the word cloud
token_freq <- tokens %>%
  group_by(word) %>%
  summarise(
    frequency = n(),
    .groups = "drop"
  ) %>%
  arrange(desc(frequency))

cat("✓ Aggregated token frequencies\n")
cat("✓ Most common token:", token_freq$word[1], 
    "(appears", token_freq$frequency[1], "times)\n\n")

# ============================================================================
# 3. OPTIONAL: FILTER TOKENS
# ============================================================================

# You can adjust these parameters to control the word cloud appearance:

# Option A: Use top N most frequent tokens only (for cleaner visualization)
top_n_tokens <- 200  # Adjust this number as needed

token_freq_filtered <- token_freq %>%
  slice_head(n = top_n_tokens)

cat("Filtered to top", top_n_tokens, "tokens for visualization\n\n")

# Option B: Alternatively, filter by minimum frequency
# Uncomment these lines if you prefer this approach:
# min_frequency <- 10
# token_freq_filtered <- token_freq %>%
#   filter(frequency >= min_frequency)

# ============================================================================
# 4. GENERATE WORD CLOUD
# ============================================================================

cat("Generating word cloud...\n")

# Set output device (high resolution PNG for presentation)
png("wordcloud_tokens.png", 
    width = 3000, 
    height = 2000, 
    res = 300,
    bg = "white")

# Set random seed for reproducibility
set.seed(42)

# Generate word cloud with professional appearance
wordcloud(
  words = token_freq_filtered$word,
  freq = token_freq_filtered$frequency,
  
  # Size parameters
  min.freq = 1,              # Show all tokens in filtered set
  max.words = 200,           # Maximum words to display
  scale = c(4, 0.5),         # Size range (largest to smallest)
  
  # Color scheme (professional blue palette)
  colors = brewer.pal(8, "Blues")[3:8],
  random.color = FALSE,      # Use palette in order (darker = more frequent)
  
  # Layout parameters
  random.order = FALSE,      # Plot most frequent words in center
  rot.per = 0.15,            # 15% of words rotated 90 degrees
  
  # Font parameters
  use.r.layout = TRUE,       # Better spacing algorithm
  family = "sans"            # Clean sans-serif font
)

# Add title
title(main = "Airline Industry News - Text Analysis",
      sub = paste("Based on", n_distinct(tokens$word), 
                  "unique tokens from", 
                  n_distinct(tokens$link), "articles"),
      cex.main = 1.5,
      cex.sub = 1)

dev.off()

cat("✓ Word cloud saved to: wordcloud_tokens.png\n\n")

# ============================================================================
# 5. GENERATE ALTERNATIVE COLOR SCHEMES (OPTIONAL)
# ============================================================================

# Option 1: Dark blue/grey professional theme
png("wordcloud_tokens_professional.png", 
    width = 3000, 
    height = 2000, 
    res = 300,
    bg = "white")

set.seed(42)
wordcloud(
  words = token_freq_filtered$word,
  freq = token_freq_filtered$frequency,
  min.freq = 1,
  max.words = 200,
  scale = c(4, 0.5),
  colors = brewer.pal(9, "Greys")[4:9],
  random.color = FALSE,
  random.order = FALSE,
  rot.per = 0.15,
  use.r.layout = TRUE,
  family = "sans"
)

title(main = "Airline Industry News - Text Analysis",
      sub = paste("Based on", n_distinct(tokens$word), 
                  "unique tokens from", 
                  n_distinct(tokens$link), "articles"),
      cex.main = 1.5,
      cex.sub = 1)

dev.off()

cat("✓ Professional theme saved to: wordcloud_tokens_professional.png\n")

# Option 2: Colorful theme (blue-green gradient)
png("wordcloud_tokens_colorful.png", 
    width = 3000, 
    height = 2000, 
    res = 300,
    bg = "white")

set.seed(42)
wordcloud(
  words = token_freq_filtered$word,
  freq = token_freq_filtered$frequency,
  min.freq = 1,
  max.words = 200,
  scale = c(4, 0.5),
  colors = brewer.pal(8, "BuGn")[3:8],
  random.color = FALSE,
  random.order = FALSE,
  rot.per = 0.15,
  use.r.layout = TRUE,
  family = "sans"
)

title(main = "Airline Industry News - Text Analysis",
      sub = paste("Based on", n_distinct(tokens$word), 
                  "unique tokens from", 
                  n_distinct(tokens$link), "articles"),
      cex.main = 1.5,
      cex.sub = 1)

dev.off()

cat("✓ Colorful theme saved to: wordcloud_tokens_colorful.png\n\n")

# ============================================================================
# 6. SUMMARY STATISTICS
# ============================================================================

cat("=== WORD CLOUD GENERATION COMPLETE ===\n\n")

cat("Summary Statistics:\n")
cat("-------------------\n")
cat("Total unique tokens:", n_distinct(tokens$word), "\n")
cat("Total token occurrences:", nrow(tokens), "\n")
cat("Tokens displayed in word cloud:", nrow(token_freq_filtered), "\n")
cat("Most frequent token:", token_freq$word[1], 
    "(", token_freq$frequency[1], "occurrences)\n")
cat("\nTop 10 most frequent tokens:\n")
print(head(token_freq, 10), n = 10)

cat("\n=== FILES GENERATED ===\n")
cat("1. wordcloud_tokens.png (Blue theme - recommended)\n")
cat("2. wordcloud_tokens_professional.png (Grey theme)\n")
cat("3. wordcloud_tokens_colorful.png (Blue-green theme)\n")
cat("\nAll images are 3000x2000px at 300 DPI (presentation quality)\n")