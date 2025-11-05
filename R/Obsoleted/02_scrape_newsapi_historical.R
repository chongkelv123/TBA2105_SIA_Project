# 02_scrape_newsapi_historical.R
# Purpose: Collect historical airline news from NewsAPI (last 1 month)
# Author: Kelvin Chong
# Date: 2025-11-02
# EMERGENCY: Get maximum historical data quickly

# Load libraries ----------------------------------------------------------
library(tidyverse)
library(httr2)
library(lubridate)
library(arrow)

# Configuration -----------------------------------------------------------

NEWSAPI_KEY <- "fd0534588700423f92fb162709119d0d"

# Free tier allows: 100 requests/day, 1 month of history
# Strategy: Multiple keyword searches to maximize coverage

SEARCH_QUERIES <- list(
  aviation = "aviation OR aircraft OR airline",
  sia = "Singapore Airlines OR SIA",
  carriers = "Cathay Pacific OR Delta Airlines OR ANA OR Lufthansa",
  industry = "airline industry OR air travel OR flight",
  events = "fuel cost OR pilot strike OR airport OR Boeing OR Airbus"
)

# Date range: Last 30 days (NewsAPI free tier limit)
DATE_TO <- Sys.Date()
DATE_FROM <- DATE_TO - days(30)

OUTPUT_DIR <- "data_interim"
LOG_DIR <- "data_raw/scrape_logs"

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

# Functions ---------------------------------------------------------------

fetch_newsapi <- function(query, from_date, to_date, api_key, page = 1) {
  
  base_url <- "https://newsapi.org/v2/everything"
  
  tryCatch({
    response <- request(base_url) %>%
      req_url_query(
        q = query,
        from = format(from_date, "%Y-%m-%d"),
        to = format(to_date, "%Y-%m-%d"),
        language = "en",
        sortBy = "publishedAt",
        pageSize = 100,  # Max per request
        page = page,
        apiKey = api_key
      ) %>%
      req_perform()
    
    data <- response %>% resp_body_json()
    
    if (data$status == "ok") {
      return(data)
    } else {
      warning(sprintf("API Error: %s", data$message))
      return(NULL)
    }
    
  }, error = function(e) {
    warning(sprintf("Request failed: %s", e$message))
    return(NULL)
  })
}

parse_newsapi_articles <- function(api_response, query_name) {
  
  if (is.null(api_response) || length(api_response$articles) == 0) {
    return(tibble())
  }
  
  articles <- map_dfr(api_response$articles, function(article) {
    tibble(
      headline = article$title %||% NA_character_,
      description = article$description %||% NA_character_,
      content = article$content %||% NA_character_,
      link = article$url %||% NA_character_,
      source = article$source$name %||% "NewsAPI",
      pub_date_raw = article$publishedAt %||% NA_character_,
      author = article$author %||% NA_character_,
      query_used = query_name
    )
  })
  
  articles <- articles %>%
    mutate(
      # Parse ISO 8601 datetime
      pub_datetime = ymd_hms(pub_date_raw, quiet = TRUE),
      pub_date = as.Date(pub_datetime),
      scraped_at = now(tzone = "UTC"),
      # Combine description and content snippet
      description = if_else(
        is.na(description) | description == "",
        str_trunc(content, 300),
        description
      )
    ) %>%
    select(-pub_date_raw, -content) %>%
    filter(!is.na(headline), !is.na(link))
  
  return(articles)
}

collect_query_articles <- function(query_name, query_string, from_date, to_date, api_key) {
  cat(sprintf("\n--- Collecting: %s ---\n", query_name))
  cat(sprintf("Query: '%s'\n", query_string))
  
  # First request to get total results
  first_response <- fetch_newsapi(query_string, from_date, to_date, api_key, page = 1)
  
  if (is.null(first_response)) {
    cat("  ✗ Failed to fetch\n")
    return(tibble())
  }
  
  total_results <- first_response$totalResults
  cat(sprintf("Total results available: %d\n", total_results))
  
  # Parse first page
  all_articles <- parse_newsapi_articles(first_response, query_name)
  cat(sprintf("  Page 1: %d articles\n", nrow(all_articles)))
  
  # Calculate how many more pages we can fetch
  # Free tier: 100 requests/day, we have 5 queries, so ~20 requests per query max
  max_pages <- min(20, ceiling(total_results / 100))
  
  if (max_pages > 1) {
    for (page in 2:max_pages) {
      Sys.sleep(1)  # Rate limiting
      
      cat(sprintf("  Page %d...\n", page))
      
      response <- fetch_newsapi(query_string, from_date, to_date, api_key, page = page)
      
      if (is.null(response)) break
      
      page_articles <- parse_newsapi_articles(response, query_name)
      
      if (nrow(page_articles) == 0) break
      
      all_articles <- bind_rows(all_articles, page_articles)
      cat(sprintf("    +%d articles (total: %d)\n", nrow(page_articles), nrow(all_articles)))
    }
  }
  
  cat(sprintf("✓ Collected %d articles for '%s'\n", nrow(all_articles), query_name))
  return(all_articles)
}

# Main Execution ----------------------------------------------------------

cat("========================================\n")
cat("NEWSAPI HISTORICAL COLLECTION\n")
cat("========================================\n")
cat("Date range:", format(DATE_FROM, "%Y-%m-%d"), "to", format(DATE_TO, "%Y-%m-%d"), "\n")
cat("Queries:", length(SEARCH_QUERIES), "\n")
cat("========================================\n")

# Collect all queries
all_articles <- map_dfr(names(SEARCH_QUERIES), function(query_name) {
  collect_query_articles(
    query_name = query_name,
    query_string = SEARCH_QUERIES[[query_name]],
    from_date = DATE_FROM,
    to_date = DATE_TO,
    api_key = NEWSAPI_KEY
  )
})

cat("\n========================================\n")
cat("DEDUPLICATION\n")
cat("========================================\n")
cat(sprintf("Before deduplication: %d articles\n", nrow(all_articles)))

# Remove duplicates based on headline similarity
deduplicated <- all_articles %>%
  distinct(headline, .keep_all = TRUE)

cat(sprintf("After deduplication: %d articles\n", nrow(deduplicated)))
cat(sprintf("Removed: %d duplicates\n", nrow(all_articles) - nrow(deduplicated)))

# Filter for airline relevance (optional - NewsAPI queries are already targeted)
AIRLINE_KEYWORDS <- c(
  "airline", "aviation", "aircraft", "airport", "flight",
  "boeing", "airbus", "carrier", "pilot", "cabin crew",
  "fuel cost", "jet fuel", "travel demand", "passenger",
  "iata", "route", "load factor", "sia", "singapore airlines",
  "cathay", "delta", "ana", "lufthansa", "qantas"
)

cat("\n========================================\n")
cat("RELEVANCE FILTERING\n")
cat("========================================\n")

airline_articles <- deduplicated %>%
  mutate(text_combined = str_to_lower(paste(headline, description))) %>%
  filter(str_detect(text_combined, regex(paste(AIRLINE_KEYWORDS, collapse = "|")))) %>%
  select(-text_combined)

cat(sprintf("Airline-relevant: %d/%d (%.1f%%)\n", 
            nrow(airline_articles), 
            nrow(deduplicated),
            100 * nrow(airline_articles) / max(nrow(deduplicated), 1)))

# Save results
output_file <- file.path(OUTPUT_DIR, "news_newsapi_historical.parquet")
write_parquet(airline_articles, output_file)

cat("\n========================================\n")
cat("RESULTS SAVED\n")
cat("========================================\n")
cat(sprintf("File: %s\n", output_file))
cat(sprintf("Articles: %d\n", nrow(airline_articles)))
cat(sprintf("Date range: %s to %s\n", 
            format(min(airline_articles$pub_date, na.rm = TRUE), "%Y-%m-%d"),
            format(max(airline_articles$pub_date, na.rm = TRUE), "%Y-%m-%d")))

# Summary by source
cat("\n--- Top Sources ---\n")
airline_articles %>%
  count(source, sort = TRUE) %>%
  head(10) %>%
  print()

# Summary by query
cat("\n--- Articles by Query ---\n")
airline_articles %>%
  count(query_used, sort = TRUE) %>%
  print()

cat("\n========================================\n")
cat("✓ Historical collection complete!\n")
cat("========================================\n")