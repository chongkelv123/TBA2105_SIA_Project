# 01_scrape_news_unified_v2.R
# Purpose: Unified news collection from multiple sources (IMPROVED)
# Sources: Google News RSS, Yahoo Finance RSS, Straits Times, Reddit
# Author: Kelvin Chong
# Date: 2025-11-02
# IMPROVEMENTS: More articles, fixed ST scraper, interactive Reddit, dual export

# Load libraries ----------------------------------------------------------
library(tidyverse)
library(xml2)
library(rvest)
library(polite)
library(httr2)
library(lubridate)
library(arrow)

# Configuration -----------------------------------------------------------

# Set to TRUE to enable Reddit collection (will prompt for password)
USE_REDDIT <- TRUE

REDDIT_CONFIG <- list(
  client_id = "-mTEpKf6PjMcwR_ebj6X6A",
  client_secret = "bbOh7a1AKiM-7NGNt4kfDbNWejQWNw",
  username = "GullibleFinger8105",
  user_agent = "TBA2105_News_Scraper:v1.0 (by /u/GullibleFinger8105)"
)

AIRLINE_KEYWORDS <- c(
  "airline", "aviation", "aircraft", "airport", "flight",
  "boeing", "airbus", "carrier", "pilot", "cabin crew",
  "fuel cost", "jet fuel", "travel demand", "passenger",
  "iata", "route", "load factor", "sia", "singapore airlines",
  "cathay", "delta", "ana", "lufthansa", "qantas",
  "airasia", "jetstar", "virgin", "emirates", "qatar airways"
)

OUTPUT_DIR <- "data_interim"
LOG_DIR <- "data_raw/scrape_logs"

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(LOG_DIR, recursive = TRUE, showWarnings = FALSE)

# SOURCE 1: RSS Feeds (EXPANDED) ------------------------------------------

scrape_rss_feeds <- function() {
  cat("\n=== SOURCE 1: RSS FEEDS ===\n")
  
  # EXPANDED: More RSS sources for more articles
  rss_sources <- list(
    google_aviation = "https://news.google.com/rss/search?q=aviation+OR+airline+OR+aircraft&hl=en-SG&gl=SG&ceid=SG:en",
    google_sia = "https://news.google.com/rss/search?q=singapore+airlines&hl=en-SG&gl=SG&ceid=SG:en",
    google_travel = "https://news.google.com/rss/search?q=air+travel+OR+flight&hl=en-SG&gl=SG&ceid=SG:en",
    google_boeing = "https://news.google.com/rss/search?q=boeing+OR+airbus&hl=en-SG&gl=SG&ceid=SG:en",
    yahoo_finance = "https://finance.yahoo.com/news/rssindex"
  )
  
  parse_rss <- function(url, source_name) {
    tryCatch({
      Sys.sleep(2)
      
      rss <- read_xml(url)
      items <- xml_find_all(rss, ".//item")
      
      if (length(items) == 0) return(tibble())
      
      tibble(
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
          pub_datetime = parse_date_time(pub_date_raw, orders = c("a, d b Y H:M:S z", "Ymd HMS"), tz = "UTC"),
          pub_date = as.Date(pub_datetime, tz = "Asia/Singapore"),
          scraped_at = now(tzone = "UTC")
        ) %>%
        select(-pub_date_raw) %>%
        filter(!is.na(headline), !is.na(link))
      
    }, error = function(e) {
      warning(sprintf("  ✗ RSS Error (%s): %s\n", source_name, e$message))
      return(tibble())
    })
  }
  
  rss_articles <- map_dfr(names(rss_sources), function(name) {
    cat(sprintf("Fetching %s...\n", name))
    articles <- parse_rss(rss_sources[[name]], paste0("RSS_", name))
    cat(sprintf("  ✓ %d articles\n", nrow(articles)))
    articles
  })
  
  cat(sprintf("Total RSS articles: %d\n", nrow(rss_articles)))
  return(rss_articles)
}

# SOURCE 2: Straits Times (FIXED) -----------------------------------------

scrape_straits_times <- function() {
  cat("\n=== SOURCE 2: STRAITS TIMES ===\n")
  
  tryCatch({
    # Try business section first
    session <- bow("https://www.straitstimes.com/business", 
                   user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")
    Sys.sleep(3)
    
    page <- scrape(session)
    
    # Try multiple selectors (ST frequently changes their HTML)
    articles <- tibble()
    
    # Selector 1: Standard cards
    cards1 <- page %>% html_elements("div.card-content")
    if (length(cards1) > 0) {
      articles <- bind_rows(articles, map_dfr(cards1, function(card) {
        headline <- card %>% html_element("a") %>% html_text2()
        link <- card %>% html_element("a") %>% html_attr("href")
        snippet <- card %>% html_element("p") %>% html_text2()
        
        if (!is.na(headline) && nchar(headline) > 0) {
          tibble(
            headline = headline,
            link = if_else(str_detect(link, "^/"), paste0("https://www.straitstimes.com", link), link),
            description = snippet %||% "",
            source = "Straits_Times",
            pub_date = Sys.Date(),
            pub_datetime = now(tzone = "UTC"),
            scraped_at = now(tzone = "UTC")
          )
        } else {
          tibble()
        }
      }))
    }
    
    # Selector 2: Alternative article format
    cards2 <- page %>% html_elements("article")
    if (length(cards2) > 0) {
      articles <- bind_rows(articles, map_dfr(cards2, function(card) {
        headline <- card %>% html_element("h3, h2") %>% html_text2()
        link <- card %>% html_element("a") %>% html_attr("href")
        snippet <- card %>% html_element("p") %>% html_text2()
        
        if (!is.na(headline) && nchar(headline) > 0) {
          tibble(
            headline = headline,
            link = if_else(str_detect(link, "^/"), paste0("https://www.straitstimes.com", link), link),
            description = snippet %||% "",
            source = "Straits_Times",
            pub_date = Sys.Date(),
            pub_datetime = now(tzone = "UTC"),
            scraped_at = now(tzone = "UTC")
          )
        } else {
          tibble()
        }
      }))
    }
    
    # Selector 3: Link-text format
    cards3 <- page %>% html_elements("a.link-text")
    if (length(cards3) > 0) {
      articles <- bind_rows(articles, map_dfr(cards3, function(link_elem) {
        headline <- link_elem %>% html_text2()
        link <- link_elem %>% html_attr("href")
        
        if (!is.na(headline) && nchar(headline) > 10) {
          tibble(
            headline = headline,
            link = if_else(str_detect(link, "^/"), paste0("https://www.straitstimes.com", link), link),
            description = "",
            source = "Straits_Times",
            pub_date = Sys.Date(),
            pub_datetime = now(tzone = "UTC"),
            scraped_at = now(tzone = "UTC")
          )
        } else {
          tibble()
        }
      }))
    }
    
    # Remove duplicates from multiple selectors
    articles <- articles %>% distinct(headline, .keep_all = TRUE)
    
    cat(sprintf("Total ST articles: %d\n", nrow(articles)))
    
    if (nrow(articles) == 0) {
      cat("  ⚠ No articles found with current selectors\n")
      cat("  Note: Straits Times may have changed their HTML structure\n")
    }
    
    return(articles)
    
  }, error = function(e) {
    warning(sprintf("  ✗ Straits Times Error: %s\n", e$message))
    cat("  Continuing without ST articles...\n")
    return(tibble())
  })
}

# SOURCE 3: Reddit (FIXED - Interactive Password) ------------------------

scrape_reddit <- function(config, use_reddit) {
  cat("\n=== SOURCE 3: REDDIT ===\n")
  
  if (!use_reddit) {
    cat("Reddit collection disabled (set USE_REDDIT = TRUE to enable)\n")
    return(tibble())
  }
  
  tryCatch({
    # Interactive password prompt
    cat("Reddit authentication required.\n")
    reddit_password <- readline(prompt = "Enter your Reddit password (or press Enter to skip): ")
    
    if (reddit_password == "") {
      cat("Skipping Reddit (no password entered)\n")
      return(tibble())
    }
    
    # Get token
    cat("Authenticating...\n")
    auth_url <- "https://www.reddit.com/api/v1/access_token"
    
    response <- request(auth_url) %>%
      req_auth_basic(config$client_id, config$client_secret) %>%
      req_body_form(
        grant_type = "password", 
        username = config$username, 
        password = reddit_password
      ) %>%
      req_user_agent(config$user_agent) %>%
      req_perform()
    
    token <- resp_body_json(response)$access_token
    cat("✓ Authenticated\n")
    
    # Search r/aviation for recent posts
    search_url <- "https://oauth.reddit.com/r/aviation/search"
    
    search_response <- request(search_url) %>%
      req_headers(
        Authorization = paste("Bearer", token), 
        `User-Agent` = config$user_agent
      ) %>%
      req_url_query(
        q = "airline OR aviation OR aircraft OR flight",
        restrict_sr = "on",
        sort = "new",
        t = "week",
        limit = 100
      ) %>%
      req_perform()
    
    posts <- resp_body_json(search_response)$data$children
    
    reddit_articles <- map_dfr(posts, function(post) {
      p <- post$data
      tibble(
        headline = p$title %||% NA_character_,
        description = str_trunc(p$selftext %||% "", 300),
        link = paste0("https://reddit.com", p$permalink %||% ""),
        source = "Reddit_aviation",
        pub_datetime = as_datetime(p$created_utc %||% NA_real_, tz = "UTC"),
        pub_date = as.Date(pub_datetime),
        scraped_at = now(tzone = "UTC")
      )
    }) %>% filter(!is.na(headline))
    
    cat(sprintf("Total Reddit articles: %d\n", nrow(reddit_articles)))
    return(reddit_articles)
    
  }, error = function(e) {
    warning(sprintf("  ✗ Reddit Error: %s\n", e$message))
    cat("  Continuing without Reddit articles...\n")
    return(tibble())
  })
}

# Main Execution ----------------------------------------------------------

cat("========================================\n")
cat("UNIFIED NEWS COLLECTION (v2)\n")
cat("========================================\n")
cat("Date:", format(Sys.Date(), "%Y-%m-%d"), "\n")
cat("Time:", format(Sys.time(), "%H:%M:%S %Z"), "\n")
cat("========================================\n")

# Collect from all sources
rss_data <- scrape_rss_feeds()
st_data <- scrape_straits_times()
reddit_data <- scrape_reddit(REDDIT_CONFIG, USE_REDDIT)

# Combine all sources
all_articles <- bind_rows(rss_data, st_data, reddit_data)

cat("\n========================================\n")
cat("CONSOLIDATION\n")
cat("========================================\n")
cat(sprintf("Total raw articles: %d\n", nrow(all_articles)))

# Deduplicate based on headline
deduplicated <- all_articles %>%
  distinct(headline, .keep_all = TRUE)

cat(sprintf("After deduplication: %d articles\n", nrow(deduplicated)))

# Filter for airline relevance
airline_articles <- deduplicated %>%
  mutate(text_combined = str_to_lower(paste(headline, description))) %>%
  filter(str_detect(text_combined, regex(paste(AIRLINE_KEYWORDS, collapse = "|")))) %>%
  select(-text_combined)

cat(sprintf("Airline-relevant: %d (%.1f%%)\n", 
            nrow(airline_articles),
            100 * nrow(airline_articles) / max(nrow(deduplicated), 1)))

# Save results (BOTH FORMATS)
timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

# Parquet (for analysis)
parquet_file <- file.path(OUTPUT_DIR, sprintf("news_unified_%s.parquet", timestamp))
write_parquet(airline_articles, parquet_file)

# CSV (for Excel/viewing)
csv_file <- file.path(OUTPUT_DIR, sprintf("news_unified_%s.csv", timestamp))
write_csv(airline_articles, csv_file)

cat("\n========================================\n")
cat("RESULTS SAVED (DUAL FORMAT)\n")
cat("========================================\n")
cat(sprintf("Parquet: %s\n", parquet_file))
cat(sprintf("CSV: %s\n", csv_file))
cat(sprintf("Articles: %d\n", nrow(airline_articles)))

# Summary by source
cat("\n--- Articles by Source ---\n")
airline_articles %>%
  count(source, sort = TRUE) %>%
  print()

# Date coverage
cat("\n--- Date Coverage ---\n")
cat(sprintf("Earliest: %s\n", min(airline_articles$pub_date, na.rm = TRUE)))
cat(sprintf("Latest: %s\n", max(airline_articles$pub_date, na.rm = TRUE)))

cat("\n========================================\n")
cat("✓ Collection complete!\n")
cat("Next run: Wait 6-8 hours for RSS refresh\n")
cat("========================================\n")