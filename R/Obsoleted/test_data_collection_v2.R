# test_data_collection_v2.R

library(tidyverse)
library(quantmod)
library(rvest)
library(xml2)
library(httr2)

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

# ===== TEST 2A: Yahoo Finance RSS (Alternative 1) =====
cat("TEST 2A: Parsing Yahoo Finance RSS feed...\n")

yahoo_test <- tryCatch({
  # Yahoo Finance Business RSS
  rss_url <- "https://finance.yahoo.com/news/rssindex"
  rss <- read_xml(rss_url)
  
  tibble(
    headline = xml_text(xml_find_all(rss, ".//item/title")),
    link = xml_text(xml_find_all(rss, ".//item/link")),
    pub_date = xml_text(xml_find_all(rss, ".//item/pubDate"))
  ) %>%
    head(10)  # First 10 articles
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  return(NULL)
})

if (!is.null(yahoo_test) && nrow(yahoo_test) > 0) {
  cat("✓ SUCCESS: Parsed", nrow(yahoo_test), "articles from Yahoo Finance\n")
  cat("\n  Sample headlines:\n")
  for(i in 1:min(3, nrow(yahoo_test))) {
    cat("  ", i, ". ", yahoo_test$headline[i], "\n", sep = "")
  }
  cat("\n")
} else {
  cat("✗ FAILED: Could not parse Yahoo Finance RSS\n\n")
}

# ===== TEST 2B: Google News RSS (Alternative 2) =====
cat("TEST 2B: Parsing Google News RSS for aviation...\n")

google_test <- tryCatch({
  # Google News RSS for "aviation" keyword
  rss_url <- "https://news.google.com/rss/search?q=aviation+OR+airline&hl=en-SG&gl=SG&ceid=SG:en"
  rss <- read_xml(rss_url)
  
  tibble(
    headline = xml_text(xml_find_all(rss, ".//item/title")),
    link = xml_text(xml_find_all(rss, ".//item/link")),
    pub_date = xml_text(xml_find_all(rss, ".//item/pubDate"))
  ) %>%
    head(10)
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  return(NULL)
})

if (!is.null(google_test) && nrow(google_test) > 0) {
  cat("✓ SUCCESS: Parsed", nrow(google_test), "articles from Google News\n")
  cat("\n  Sample headlines:\n")
  for(i in 1:min(3, nrow(google_test))) {
    cat("  ", i, ". ", google_test$headline[i], "\n", sep = "")
  }
  cat("\n")
} else {
  cat("✗ FAILED: Could not parse Google News RSS\n\n")
}

# ===== TEST 2C: Web Scraping Reuters Search (Your URL) =====
cat("TEST 2C: Scraping Reuters search results...\n")

reuters_scrape_test <- tryCatch({
  # Your URL - search results page
  url <- "https://www.reuters.com/site-search/?query=airline&section=business"
  
  # Add delay and proper headers
  Sys.sleep(2)
  
  page <- request(url) %>%
    req_user_agent("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36") %>%
    req_perform() %>%
    resp_body_html()
  
  # Extract headlines (you may need to adjust selectors)
  headlines <- page %>%
    html_elements("h3, .search-result-title") %>%
    html_text2() %>%
    str_squish()
  
  # Extract links
  links <- page %>%
    html_elements("a[data-testid='Heading']") %>%
    html_attr("href")
  
  if (length(headlines) > 0) {
    tibble(
      headline = headlines,
      link = if(length(links) > 0) links else NA_character_
    ) %>%
      head(5)
  } else {
    NULL
  }
  
}, error = function(e) {
  cat("ERROR:", e$message, "\n")
  return(NULL)
})

if (!is.null(reuters_scrape_test) && nrow(reuters_scrape_test) > 0) {
  cat("✓ SUCCESS: Scraped", nrow(reuters_scrape_test), "headlines from Reuters\n")
  cat("\n  Sample headlines:\n")
  for(i in 1:nrow(reuters_scrape_test)) {
    cat("  ", i, ". ", reuters_scrape_test$headline[i], "\n", sep = "")
  }
  cat("\n")
} else {
  cat("✗ FAILED: Could not scrape Reuters\n\n")
}

# ===== TEST 3: Can we filter airline news? =====
cat("TEST 3: Filtering for airline-related news...\n")

# Use whichever source worked
news_data <- if(!is.null(google_test)) {
  google_test
} else if(!is.null(yahoo_test)) {
  yahoo_test
} else if(!is.null(reuters_scrape_test)) {
  reuters_scrape_test
} else {
  NULL
}

if (!is.null(news_data)) {
  airline_keywords <- c("airline", "aviation", "aircraft", "airport", "flight", 
                        "boeing", "airbus", "carrier", "sia", "singapore airlines")
  
  airline_test <- news_data %>%
    filter(str_detect(str_to_lower(headline), 
                      regex(paste(airline_keywords, collapse = "|"))))
  
  cat("✓ Found", nrow(airline_test), "airline-related articles out of", nrow(news_data), "\n")
  
  if (nrow(airline_test) > 0) {
    cat("\n  Airline headlines:\n")
    for(i in 1:min(3, nrow(airline_test))) {
      cat("  ", i, ". ", airline_test$headline[i], "\n", sep = "")
    }
  }
  cat("\n")
}

# ===== SUMMARY =====
cat("========================================\n")
cat("SETUP TEST SUMMARY\n")
cat("========================================\n")
cat("Stock data:        ", ifelse(!is.null(sia_test), "✓ Working", "✗ Failed"), "\n")
cat("Yahoo Finance RSS: ", ifelse(!is.null(yahoo_test) && nrow(yahoo_test) > 0, "✓ Working", "✗ Failed"), "\n")
cat("Google News RSS:   ", ifelse(!is.null(google_test) && nrow(google_test) > 0, "✓ Working", "✗ Failed"), "\n")
cat("Reuters scraping:  ", ifelse(!is.null(reuters_scrape_test) && nrow(reuters_scrape_test) > 0, "✓ Working", "✗ Failed"), "\n")
cat("Text filtering:    ", ifelse(exists("airline_test") && nrow(airline_test) > 0, "✓ Working", "✗ Failed"), "\n")
cat("========================================\n")

# ===== RECOMMENDATION =====
cat("\nRECOMMENDATION:\n")
if (!is.null(google_test) && nrow(google_test) > 0) {
  cat("→ Use Google News RSS as primary source (most reliable)\n")
}
if (!is.null(yahoo_test) && nrow(yahoo_test) > 0) {
  cat("→ Use Yahoo Finance RSS as secondary source\n")
}
if (!is.null(reuters_scrape_test) && nrow(reuters_scrape_test) > 0) {
  cat("→ Reuters web scraping works but requires careful CSS selector maintenance\n")
}