# 01_scrape_news.R
# Purpose: Collect airline industry news from RSS feeds
# Author: Kelvin Chong
# Date: 2024-10-26
# Note: Reuters scraping removed due to 401 auth requirement

# Load libraries ----------------------------------------------------------
library(tidyverse)
library(xml2)
library(lubridate)
library(arrow)

# Configuration -----------------------------------------------------------

NEWS_SOURCES <- list(
  google_aviation = list(
    name = "Google_News_Aviation",
    url = "https://news.google.com/rss/search?q=aviation+OR+airline+OR+aircraft&hl=en-SG&gl=SG&ceid=SG:en"
  ),
  google_sia = list(
    name = "Google_News_SIA",
    url = "https://news.google.com/rss/search?q=singapore+airlines&hl=en-SG&gl=SG&ceid=SG:en"
  ),
  yahoo_finance = list(
    name = "Yahoo_Finance",
    url = "https://finance.yahoo.com/news/rssindex"
  )
)

AIRLINE_KEYWORDS <- c(
  "airline", "aviation", "aircraft", "airport", "flight",
  "boeing", "airbus", "carrier", "pilot", "cabin crew",
  "fuel cost", "jet fuel", "travel demand", "passenger",
  "iata", "route", "load factor", "sia", "singapore airlines",
  "cathay", "delta", "ana", "lufthansa", "qantas"
)

OUTPUT_DIR <- "data_interim"
LOG_DIR <- "data_raw/scrape_logs"

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

# Functions ---------------------------------------------------------------

parse_rss_feed <- function(rss_url, source_name) {
  cat(sprintf("Fetching %s...\n", source_name))
  
  tryCatch({
    Sys.sleep(2)  # Politeness delay
    
    rss <- read_xml(rss_url)
    items <- xml_find_all(rss, ".//item")
    
    if (length(items) == 0) {
      warning(sprintf("  No items found in %s\n", source_name))
      return(tibble())
    }
    
    result <- tibble(
      headline = xml_text(xml_find_first(items, ".//title")),
      link = xml_text(xml_find_first(items, ".//link")),
      pub_date_raw = xml_text(xml_find_first(items, ".//pubDate")),
      description = xml_text(xml_find_first(items, ".//description")),
      source = source_name
    ) %>%
      mutate(
        description = str_remove_all(description, "<.*?>"),
        description = str_squish(description),
        description = str_trunc(description, 300),
        pub_datetime = parse_date_time(
          pub_date_raw,
          orders = c("a, d b Y H:M:S z", "Y-m-d H:M:S", "Y-m-dTH:M:SZ"),
          quiet = TRUE
        ),
        pub_date = as.Date(pub_datetime, tz = "Asia/Singapore"),
        scraped_at = now(tzone = "UTC")
      ) %>%
      select(-pub_date_raw) %>%
      filter(!is.na(headline), !is.na(link))
    
    cat(sprintf("  ✓ Fetched %d articles\n", nrow(result)))
    return(result)
    
  }, error = function(e) {
    warning(sprintf("  ✗ Error: %s\n", e$message))
    tibble(
      timestamp = Sys.time(),
      source = source_name,
      error = e$message
    ) %>%
      write_csv(file.path(LOG_DIR, "scraping_errors.csv"), append = TRUE)
    
    return(tibble())
  })
}

# Main execution ----------------------------------------------------------

cat("========================================\n")
cat("NEWS COLLECTION - Airline Industry\n")
cat("========================================\n")
cat("Date:", format(Sys.Date(), "%Y-%m-%d"), "\n")
cat("Time:", format(Sys.time(), "%H:%M:%S %Z"), "\n")
cat("========================================\n\n")

# Collect from all sources
all_news <- map_dfr(NEWS_SOURCES, ~parse_rss_feed(.x$url, .x$name))

cat("\n")
cat("Total articles collected:", nrow(all_news), "\n")

if (nrow(all_news) == 0) {
  stop("❌ No articles collected. Check sources and internet connection.")
}

# Filter for airline-relevant articles
cat("\nFiltering for airline keywords...\n")
airline_news <- all_news %>%
  mutate(text_combined = str_to_lower(paste(headline, description))) %>%
  filter(str_detect(text_combined, regex(paste(AIRLINE_KEYWORDS, collapse = "|")))) %>%
  select(-text_combined) %>%
  distinct(headline, .keep_all = TRUE)

cat(sprintf("  Kept %d/%d articles (%.1f%%)\n", 
            nrow(airline_news), 
            nrow(all_news),
            100 * nrow(airline_news) / max(nrow(all_news), 1)))

# Save results
output_file <- file.path(OUTPUT_DIR, "news_raw.parquet")
write_parquet(airline_news, output_file)
cat(sprintf("\n✓ Saved to: %s\n", output_file))

# Summary
cat("\n========================================\n")
cat("SUMMARY\n")
cat("========================================\n")
all_news %>%
  count(source, name = "articles") %>%
  arrange(desc(articles)) %>%
  print()

cat("========================================\n")
cat("Airline articles:", nrow(airline_news), "\n")
cat("Date range:", 
    format(min(airline_news$pub_date, na.rm = TRUE), "%Y-%m-%d"), "to",
    format(max(airline_news$pub_date, na.rm = TRUE), "%Y-%m-%d"), "\n")
cat("========================================\n")