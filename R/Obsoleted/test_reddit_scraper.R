# test_reddit_scraper.R
# Purpose: Test Reddit API access for airline industry posts
# Target: r/aviation subreddit, last 2 years
# Author: Kelvin Chong
# Date: 2025-11-02

# Load libraries ----------------------------------------------------------
library(tidyverse)
library(httr2)
library(jsonlite)
library(lubridate)

# Reddit API Configuration ------------------------------------------------

REDDIT_CONFIG <- list(
  client_id = "-mTEpKf6PjMcwR_ebj6X6A",
  client_secret = "bbOh7a1AKiM-7NGNt4kfDbNWejQWNw",
  username = "GullibleFinger8105",
  user_agent = "TBA2105_News_Scraper:v1.0 (by /u/GullibleFinger8105)"
)

# Airline keywords for filtering
AIRLINE_KEYWORDS <- c(
  "airline", "aviation", "aircraft", "airport", "flight",
  "boeing", "airbus", "carrier", "pilot", "cabin crew",
  "fuel cost", "jet fuel", "travel demand", "passenger",
  "iata", "route", "load factor", "sia", "singapore airlines",
  "cathay", "delta", "ana", "lufthansa", "qantas"
)

# Functions ---------------------------------------------------------------

get_reddit_token <- function(config) {
  cat("Authenticating with Reddit API...\n")
  
  auth_url <- "https://www.reddit.com/api/v1/access_token"
  
  response <- request(auth_url) %>%
    req_auth_basic(config$client_id, config$client_secret) %>%
    req_body_form(
      grant_type = "password",
      username = config$username,
      password = readline(prompt = "Enter your Reddit password: ")
    ) %>%
    req_user_agent(config$user_agent) %>%
    req_perform()
  
  token_data <- response %>% resp_body_json()
  
  if (!is.null(token_data$access_token)) {
    cat("✓ Authentication successful!\n\n")
    return(token_data$access_token)
  } else {
    stop("❌ Authentication failed. Check credentials.")
  }
}

search_reddit_posts <- function(token, subreddit, query, config, limit = 1000) {
  cat(sprintf("Searching r/%s for: '%s'\n", subreddit, query))
  cat(sprintf("Limit: %d posts\n\n", limit))
  
  base_url <- "https://oauth.reddit.com"
  search_endpoint <- sprintf("/r/%s/search", subreddit)
  
  all_posts <- list()
  after <- NULL
  fetched <- 0
  
  while (fetched < limit) {
    cat(sprintf("Fetching batch... (total so far: %d)\n", fetched))
    
    # Build request
    req <- request(paste0(base_url, search_endpoint)) %>%
      req_headers(
        Authorization = paste("Bearer", token),
        `User-Agent` = config$user_agent
      ) %>%
      req_url_query(
        q = query,
        restrict_sr = "on",
        sort = "new",
        t = "all",
        limit = min(100, limit - fetched)  # Reddit max 100 per request
      )
    
    # Add 'after' parameter for pagination
    if (!is.null(after)) {
      req <- req %>% req_url_query(after = after)
    }
    
    # Perform request with error handling
    response <- tryCatch({
      req %>% req_perform()
    }, error = function(e) {
      cat(sprintf("  ✗ Error: %s\n", e$message))
      return(NULL)
    })
    
    if (is.null(response)) break
    
    # Parse response
    data <- response %>% resp_body_json()
    
    posts <- data$data$children
    
    if (length(posts) == 0) {
      cat("  No more posts available.\n")
      break
    }
    
    all_posts <- c(all_posts, posts)
    fetched <- length(all_posts)
    
    # Get pagination token
    after <- data$data$after
    
    if (is.null(after)) {
      cat("  Reached end of results.\n")
      break
    }
    
    # Be polite - rate limiting
    Sys.sleep(2)
  }
  
  cat(sprintf("\n✓ Total posts fetched: %d\n\n", length(all_posts)))
  return(all_posts)
}

parse_reddit_posts <- function(posts_raw) {
  cat("Parsing post data...\n")
  
  parsed <- map_dfr(posts_raw, function(post) {
    p <- post$data
    
    tibble(
      post_id = p$id %||% NA_character_,
      title = p$title %||% NA_character_,
      selftext = p$selftext %||% NA_character_,
      author = p$author %||% NA_character_,
      subreddit = p$subreddit %||% NA_character_,
      score = p$score %||% 0,
      num_comments = p$num_comments %||% 0,
      created_utc = p$created_utc %||% NA_real_,
      url = p$url %||% NA_character_,
      permalink = paste0("https://reddit.com", p$permalink %||% "")
    )
  })
  
  # Convert Unix timestamp to datetime
  parsed <- parsed %>%
    mutate(
      created_datetime = as_datetime(created_utc, tz = "UTC"),
      created_date = as.Date(created_datetime),
      text_combined = str_to_lower(paste(title, selftext))
    )
  
  cat(sprintf("✓ Parsed %d posts\n\n", nrow(parsed)))
  return(parsed)
}

filter_airline_posts <- function(posts_df, keywords) {
  cat("Filtering for airline-related posts...\n")
  
  pattern <- regex(paste(keywords, collapse = "|"), ignore_case = TRUE)
  
  airline_posts <- posts_df %>%
    filter(str_detect(text_combined, pattern)) %>%
    select(-text_combined)
  
  cat(sprintf("✓ Kept %d/%d posts (%.1f%%)\n\n", 
              nrow(airline_posts), 
              nrow(posts_df),
              100 * nrow(airline_posts) / max(nrow(posts_df), 1)))
  
  return(airline_posts)
}

# Main Execution ----------------------------------------------------------

cat("========================================\n")
cat("REDDIT TEST SCRAPER\n")
cat("Target: r/aviation (last 2 years)\n")
cat("========================================\n\n")

# Step 1: Authenticate
token <- get_reddit_token(REDDIT_CONFIG)

# Step 2: Search r/aviation
# Search for broad aviation terms to capture all relevant posts
search_query <- "airline OR aviation OR aircraft OR flight"

posts_raw <- search_reddit_posts(
  token = token,
  subreddit = "aviation",
  query = search_query,
  config = REDDIT_CONFIG,
  limit = 1000  # Test with 1000 posts first
)

if (length(posts_raw) == 0) {
  stop("❌ No posts retrieved. Check API access.")
}

# Step 3: Parse posts
posts_df <- parse_reddit_posts(posts_raw)

# Step 4: Filter for airline relevance
airline_posts <- filter_airline_posts(posts_df, AIRLINE_KEYWORDS)

# Step 5: Analyze results
cat("========================================\n")
cat("DATA QUALITY ASSESSMENT\n")
cat("========================================\n\n")

# Date range
cat("Date Range:\n")
cat(sprintf("  Earliest: %s\n", min(airline_posts$created_date, na.rm = TRUE)))
cat(sprintf("  Latest: %s\n", max(airline_posts$created_date, na.rm = TRUE)))
date_span <- as.numeric(difftime(
  max(airline_posts$created_date, na.rm = TRUE),
  min(airline_posts$created_date, na.rm = TRUE),
  units = "days"
))
cat(sprintf("  Span: %.0f days (%.1f months)\n\n", date_span, date_span/30))

# Volume statistics
cat("Volume Statistics:\n")
cat(sprintf("  Total airline posts: %d\n", nrow(airline_posts)))
cat(sprintf("  Average per day: %.1f\n", nrow(airline_posts) / max(date_span, 1)))
cat(sprintf("  Average per week: %.1f\n\n", nrow(airline_posts) / max(date_span/7, 1)))

# Engagement statistics
cat("Engagement Statistics:\n")
cat(sprintf("  Median score: %.0f\n", median(airline_posts$score, na.rm = TRUE)))
cat(sprintf("  Median comments: %.0f\n", median(airline_posts$num_comments, na.rm = TRUE)))
cat(sprintf("  High engagement (>50 score): %d posts\n\n", 
            sum(airline_posts$score > 50, na.rm = TRUE)))

# Sample posts
cat("========================================\n")
cat("SAMPLE POSTS (Top 10 by Score)\n")
cat("========================================\n\n")

airline_posts %>%
  arrange(desc(score)) %>%
  head(10) %>%
  select(created_date, score, num_comments, title) %>%
  mutate(title = str_trunc(title, 70)) %>%
  print(n = 10)

cat("\n========================================\n")
cat("RECOMMENDATION\n")
cat("========================================\n\n")

posts_per_day <- nrow(airline_posts) / max(date_span, 1)

if (posts_per_day >= 20) {
  cat("✅ EXCELLENT: Reddit provides substantial data volume.\n")
  cat("   Recommend: Include Reddit in unified scraper.\n")
} else if (posts_per_day >= 10) {
  cat("✓ GOOD: Reddit provides moderate data volume.\n")
  cat("   Recommend: Include as supplementary source.\n")
} else if (posts_per_day >= 5) {
  cat("⚠ MARGINAL: Reddit provides limited data volume.\n")
  cat("   Recommend: Consider only if easy to implement.\n")
} else {
  cat("❌ INSUFFICIENT: Reddit data volume too low.\n")
  cat("   Recommend: Focus on RSS feeds instead.\n")
}

cat("\n========================================\n")
cat("Test Complete!\n")
cat("========================================\n")