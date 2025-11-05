# test_data_collection.R
# Purpose: Verify we can collect stock prices and scrape news

library(tidyverse)
library(quantmod)
library(rvest)
library(xml2)

# ===== TEST 1: Can we get SIA stock data? =====
cat("TEST 1: Downloading SIA stock prices...\n")

sia_test <- tryCatch({
  getSymbols("C6L.SI", 
             from = "2024-01-01", 
             to = Sys.Date(), 
             auto.assign = FALSE)
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  return(NULL)
})

if (!is.null(sia_test)) {
  cat("✓ SUCCESS: Downloaded", nrow(sia_test), "days of SIA data\n")
  cat("  Latest close:", as.numeric(tail(sia_test[,4], 1)), "SGD\n\n")
} else {
  cat("✗ FAILED: Could not download SIA data\n\n")
}

# ===== TEST 2: Can we parse RSS feed? =====
cat("TEST 2: Parsing Reuters RSS feed...\n")

reuters_test <- tryCatch({
  rss_url <- "https://www.reuters.com/rssfeed/businessNews"
  rss <- read_xml(rss_url)
  
  tibble(
    headline = xml_text(xml_find_all(rss, ".//item/title")),
    link = xml_text(xml_find_all(rss, ".//item/link")),
    pub_date = xml_text(xml_find_all(rss, ".//item/pubDate"))
  ) %>%
    head(5)  # Just first 5 articles
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  return(NULL)
})

if (!is.null(reuters_test) && nrow(reuters_test) > 0) {
  cat("✓ SUCCESS: Parsed", nrow(reuters_test), "articles from Reuters\n")
  cat("\n  Sample headlines:\n")
  print(reuters_test$headline, width = 80)
  cat("\n")
} else {
  cat("✗ FAILED: Could not parse Reuters RSS\n\n")
}

# ===== TEST 3: Can we filter airline news? =====
cat("TEST 3: Filtering for airline-related news...\n")

if (!is.null(reuters_test)) {
  airline_keywords <- c("airline", "aviation", "aircraft", "airport", "flight", "boeing", "airbus")
  
  airline_test <- reuters_test %>%
    filter(str_detect(str_to_lower(headline), 
                      regex(paste(airline_keywords, collapse = "|"))))
  
  cat("✓ Found", nrow(airline_test), "airline-related articles out of", nrow(reuters_test), "\n")
  
  if (nrow(airline_test) > 0) {
    cat("\n  Airline headlines:\n")
    print(airline_test$headline, width = 80)
  }
  cat("\n")
}

# ===== SUMMARY =====
cat("========================================\n")
cat("SETUP TEST SUMMARY\n")
cat("========================================\n")
cat("Stock data:   ", ifelse(!is.null(sia_test), "✓ Working", "✗ Failed"), "\n")
cat("RSS parsing:  ", ifelse(!is.null(reuters_test), "✓ Working", "✗ Failed"), "\n")
cat("Text filtering:", ifelse(exists("airline_test") && nrow(airline_test) > 0, "✓ Working", "✗ Failed"), "\n")
cat("========================================\n")