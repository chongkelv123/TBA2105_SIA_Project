# ============================================================================
# TBA2105 Web Mining - Project
# Straits Times Business News Scraper (RSelenium)
# 
# Student Name: KELVIN, CHONG KEAN SIONG
# Date: October 26, 2025
# 
# Purpose: Scrape airline industry news from Straits Times Business section
# Method: RSelenium (handles React-rendered content)
# Strategy: Use search results page with pre-filtered keywords (smart!)
#           URL already filters for: airline OR aviation OR flight
# ============================================================================

# Required Libraries
library(RSelenium)
library(rvest)
library(dplyr)
library(stringr)
library(lubridate)

# ============================================================================
# SECTION 1: CONFIGURATION
# ============================================================================

# Target URL - Using search with airline keywords (pre-filtered!)
ST_BUSINESS_URL <- "https://www.straitstimes.com/search?searchkey=airline+or+aviation+or+flight&sort=relevancydate"

# Airline-related keywords for filtering
AIRLINE_KEYWORDS <- c(
  "airline", "aviation", "aircraft", "airport", "flight",
  "boeing", "airbus", "carrier", "sia", "singapore airlines",
  "cathay", "pilot", "cabin crew", "travel", "passenger"
)

# Scraping parameters
MAX_LOAD_MORE_CLICKS <- 3     # How many times to click "Load More" button
LOAD_BUTTON_PAUSE_SEC <- 3    # Seconds to wait after each click
PAGE_LOAD_TIMEOUT_SEC <- 10   # Initial page load timeout
EXTRACT_SNIPPETS <- TRUE      # Set FALSE to skip snippet extraction (faster)
SNIPPET_PAGE_WAIT_SEC <- 3    # Seconds to wait for article page to load

# Output configuration
OUTPUT_DIR <- "data_interim"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# ============================================================================
# SECTION 2: HELPER FUNCTIONS
# ============================================================================

# Initialize RSelenium driver (Firefox - more stable than Chrome)
initializeDriver <- function(port = 4567L) {
  cat("Initializing RSelenium driver (Firefox)...\n")
  
  tryCatch({
    driver <- rsDriver(
      browser = "firefox",
      port = port,
      verbose = FALSE,           # Set TRUE for debugging
      check = TRUE,
      chromever = NULL,
      geckover = "latest",       # Auto-download latest Firefox driver
      iedrver = NULL,
      phantomver = NULL
    )
    
    cat("✓ Driver initialized successfully\n")
    return(driver)
    
  }, error = function(e) {
    cat("✗ Error initializing driver:", e$message, "\n")
    cat("Troubleshooting tips:\n")
    cat("  1. Ensure Firefox is installed\n")
    cat("  2. Check if port", port, "is available\n")
    cat("  3. Try a different port (e.g., 4568L)\n")
    return(NULL)
  })
}

# Navigate to page and wait for content to load
navigateToPage <- function(remoteDriver, url, wait_sec = 5) {
  cat("Navigating to:", url, "\n")
  
  remoteDriver$navigate(url)
  Sys.sleep(wait_sec)  # Wait for initial page load
  
  cat("✓ Page loaded\n")
}

# Click "Load More" button to load additional articles
clickLoadMoreButton <- function(remoteDriver, num_clicks = 3, pause_sec = 3) {
  cat("Clicking 'Load More' button to load additional articles...\n")
  
  for (i in 1:num_clicks) {
    tryCatch({
      cat("  Click attempt", i, "of", num_clicks, "\n")
      
      # Find the "Load More" button
      loadButton <- remoteDriver$findElement(
        using = "css", 
        value = '[data-testid="load-more-test-id"]'
      )
      
      # Scroll button into view first (important for React components)
      remoteDriver$executeScript("arguments[0].scrollIntoView(true);", list(loadButton))
      Sys.sleep(1)  # Brief pause after scroll
      
      # Click the button
      loadButton$clickElement()
      
      # Wait for new content to load
      Sys.sleep(pause_sec)
      
      cat("  ✓ Button clicked, waiting for content...\n")
      
    }, error = function(e) {
      cat("  ⚠ Could not click 'Load More' button (might not exist or already loaded all)\n")
      cat("    Error:", e$message, "\n")
      break  # Exit loop if button not found
    })
  }
  
  cat("✓ Load More clicking complete\n")
}

# Extract snippet from individual article page (all paragraphs combined)
extractArticleSnippet <- function(remoteDriver, article_url, max_wait = 5) {
  tryCatch({
    # Navigate to article page
    remoteDriver$navigate(article_url)
    Sys.sleep(max_wait)  # Wait for page to load
    
    # Extract ALL paragraph elements (not just first one)
    snippet_elems <- remoteDriver$findElements(
      using = "css", 
      value = "p.font-body-baseline-regular.text-primary"
    )
    
    # If no paragraphs found, return NA
    if (length(snippet_elems) == 0) {
      return(NA)
    }
    
    # Extract text from all paragraphs and combine
    all_paragraphs <- sapply(snippet_elems, function(elem) {
      tryCatch({
        elem$getElementText()[[1]]
      }, error = function(e) NA)
    })
    
    # Remove NA values and combine with newlines
    all_paragraphs <- all_paragraphs[!is.na(all_paragraphs)]
    snippet <- paste(all_paragraphs, collapse = "\n")
    
    return(snippet)
    
  }, error = function(e) {
    # If snippet extraction fails, return NA
    return(NA)
  })
}

# Filter articles by airline keywords
filterAirlineNews <- function(articles_df, keywords) {
  if (nrow(articles_df) == 0) return(articles_df)
  
  # Create combined text for searching
  articles_df <- articles_df %>%
    mutate(text_combined = tolower(paste(headline, snippet, sep = " ")))
  
  # Filter for airline-related content
  pattern <- paste(keywords, collapse = "|")
  filtered <- articles_df %>%
    filter(str_detect(text_combined, regex(pattern, ignore_case = TRUE))) %>%
    select(-text_combined)
  
  cat("Filtered:", nrow(filtered), "airline-related articles out of", 
      nrow(articles_df), "total\n")
  
  return(filtered)
}

# ============================================================================
# SECTION 3: MAIN SCRAPING FUNCTION
# ============================================================================

# Main scraper function
scrapeStraitsTimesNews <- function() {
  cat("========================================\n")
  cat("Straits Times Business News Scraper\n")
  cat("========================================\n\n")
  
  # Step 1: Initialize driver
  driver <- initializeDriver()
  if (is.null(driver)) {
    cat("✗ Failed to initialize driver. Aborting.\n")
    return(data.frame())
  }
  
  remoteDriver <- driver[["client"]]
  
  # Step 2: Navigate to page
  articles_df <- data.frame()  # Initialize to prevent error in finally block
  
  tryCatch({
    navigateToPage(remoteDriver, ST_BUSINESS_URL, wait_sec = PAGE_LOAD_TIMEOUT_SEC)
    
    # Step 3: Click "Load More" button to load additional articles
    clickLoadMoreButton(remoteDriver, num_clicks = MAX_LOAD_MORE_CLICKS, pause_sec = LOAD_BUTTON_PAUSE_SEC)
    
    # ========================================================================
    # Step 4: EXTRACT ARTICLES (CSS SELECTORS - TESTED & WORKING)
    # ========================================================================
    
    cat("\nExtracting articles...\n")
    
    # CSS SELECTORS - Tested by Kelvin on Oct 26, 2025
    # URL: https://www.straitstimes.com/search?searchkey=airline+or+aviation+or+flight
    # Test result: 32 articles found after clicking "Load More" 3 times
    
    SELECTOR_ARTICLE_CONTAINER <- "div.search-result-list > a.select-none.card.basis-full"
    SELECTOR_HEADLINE <- "h4.font-header-sm-semibold"
    SELECTOR_LINK <- "a"  # Link is within the article container
    SELECTOR_DATE <- ".font-eyebrow-baseline-regular.text-tertiary"
    # Note: Snippet available by visiting individual article pages
    
    # Find all article containers
    articleElements <- remoteDriver$findElements(
      using = "css", 
      value = SELECTOR_ARTICLE_CONTAINER
    )
    
    cat("Found", length(articleElements), "article elements\n\n")
    
    if (EXTRACT_SNIPPETS && length(articleElements) > 0) {
      cat("⚠ Snippet extraction ENABLED - this will be slower (~3 sec per article)\n")
      cat("  Estimated time: ~", length(articleElements) * SNIPPET_PAGE_WAIT_SEC, "seconds\n")
      cat("  Set EXTRACT_SNIPPETS = FALSE to skip this step\n\n")
    }
    
    if (length(articleElements) == 0) {
      cat("⚠ No articles found. Check CSS selectors!\n")
      cat("Tips:\n")
      cat("  1. Inspect page in Firefox (F12)\n")
      cat("  2. Find repeating article elements\n")
      cat("  3. Test selector in Console: document.querySelectorAll('YOUR_SELECTOR')\n")
      cat("  4. Update SELECTOR_* variables above\n\n")
    }
    
    # Extract data from each article
    all_articles <- list()
    
    # First pass: Extract all links and metadata (avoid stale element issues)
    cat("Step 1: Extracting article metadata from search results...\n")
    article_metadata <- list()
    
    for (i in seq_along(articleElements)) {
      tryCatch({
        article <- articleElements[[i]]
        
        # Extract headline
        headline <- tryCatch({
          headline_elem <- article$findChildElement(using = "css", value = SELECTOR_HEADLINE)
          headline_elem$getElementText()[[1]]
        }, error = function(e) NA)
        
        # Extract link - the article container itself is the <a> tag!
        link <- tryCatch({
          article$getElementAttribute("href")[[1]]
        }, error = function(e) NA)
        
        # Extract date
        date_text <- tryCatch({
          date_elem <- article$findChildElement(using = "css", value = SELECTOR_DATE)
          date_elem$getElementText()[[1]]
        }, error = function(e) NA)
        
        # Skip if no headline or link found
        if (is.na(headline) || is.na(link)) {
          next
        }
        
        # Make absolute URL if needed
        if (!grepl("^http", link)) {
          link <- paste0("https://www.straitstimes.com", link)
        }
        
        # Store metadata
        article_metadata[[length(article_metadata) + 1]] <- list(
          headline = headline,
          link = link,
          date_text = date_text
        )
        
        # Progress indicator
        if (i %% 10 == 0) {
          cat("  Processed", i, "/", length(articleElements), "articles\n")
        }
        
      }, error = function(e) {
        cat("  ⚠ Error extracting metadata for article", i, ":", e$message, "\n")
      })
    }
    
    cat("✓ Extracted metadata for", length(article_metadata), "articles\n\n")
    
    # Second pass: Visit each article page to extract snippets (if enabled)
    if (EXTRACT_SNIPPETS && length(article_metadata) > 0) {
      cat("Step 2: Extracting snippets from individual article pages...\n")
      
      for (i in seq_along(article_metadata)) {
        meta <- article_metadata[[i]]
        
        # Extract snippet by visiting article page
        cat("  Article", i, "/", length(article_metadata), ":", substr(meta$headline, 1, 50), "...\n")
        snippet <- extractArticleSnippet(remoteDriver, meta$link, max_wait = SNIPPET_PAGE_WAIT_SEC)
        
        # Store complete article data
        article_data <- data.frame(
          headline = meta$headline,
          link = meta$link,
          date_text = meta$date_text,
          snippet = snippet,
          source = "Straits_Times",
          scraped_at = Sys.time(),
          stringsAsFactors = FALSE
        )
        
        all_articles[[length(all_articles) + 1]] <- article_data
        
        # Progress indicator
        if (i %% 5 == 0) {
          cat("  Completed", i, "/", length(article_metadata), "articles (with snippets)\n")
        }
      }
    } else {
      # No snippet extraction - just use metadata
      for (meta in article_metadata) {
        article_data <- data.frame(
          headline = meta$headline,
          link = meta$link,
          date_text = meta$date_text,
          snippet = NA,
          source = "Straits_Times",
          scraped_at = Sys.time(),
          stringsAsFactors = FALSE
        )
        
        all_articles[[length(all_articles) + 1]] <- article_data
      }
    }
    
    # Combine all articles
    if (length(all_articles) > 0) {
      articles_df <- bind_rows(all_articles)
      cat("\n✓ Extracted", nrow(articles_df), "articles successfully\n")
    } else {
      articles_df <- data.frame()
      cat("\n✗ No articles extracted\n")
    }
    
  }, error = function(e) {
    cat("✗ Error during scraping:", e$message, "\n")
    articles_df <- data.frame()
    
  }, finally = {
    # Step 5: Cleanup (ALWAYS close browser and stop server)
    cat("\nCleaning up...\n")
    tryCatch({
      remoteDriver$close()
      cat("✓ Browser closed\n")
    }, error = function(e) {
      cat("⚠ Error closing browser:", e$message, "\n")
    })
    
    tryCatch({
      driver[["server"]]$stop()
      cat("✓ Selenium server stopped\n")
    }, error = function(e) {
      cat("⚠ Error stopping server:", e$message, "\n")
    })
  })
  
  # Step 6: Note - Filtering not needed (URL already filters for airline keywords)
  cat("\nNote: Articles already filtered by search keywords in URL\n")
  
  # Step 7: Save results
  if (nrow(articles_df) > 0) {
    output_file <- file.path(OUTPUT_DIR, "straits_times_news.csv")
    write.csv(articles_df, output_file, row.names = FALSE)
    cat("\n✓ Saved", nrow(articles_df), "articles to:", output_file, "\n")
  } else {
    cat("\n⚠ No articles to save\n")
  }
  
  cat("\n========================================\n")
  cat("Scraping complete!\n")
  cat("========================================\n\n")
  
  return(articles_df)
}

# ============================================================================
# SECTION 4: EXECUTION
# ============================================================================

# Run the scraper
cat("TBA2105 Project - Straits Times Scraper\n")
cat("Starting scraping process...\n\n")

# Execute the scraper
straits_times_data <- scrapeStraitsTimesNews()

# Display results
if (nrow(straits_times_data) > 0) {
  cat("\n===== PREVIEW OF SCRAPED DATA =====\n")
  print(head(straits_times_data, 10))
  
  cat("\n===== DATA SUMMARY =====\n")
  cat("Total articles:", nrow(straits_times_data), "\n")
  cat("With snippets:", sum(!is.na(straits_times_data$snippet)), "\n")
  cat("With dates:", sum(!is.na(straits_times_data$date_text)), "\n")
  
  # Sample headlines
  cat("\n===== SAMPLE HEADLINES =====\n")
  sample_headlines <- head(straits_times_data$headline, 5)
  for (i in seq_along(sample_headlines)) {
    cat(i, ".", sample_headlines[i], "\n")
  }
} else {
  cat("\n⚠ No data collected. Please:\n")
  cat("  1. Check your CSS selectors\n")
  cat("  2. Ensure Firefox is installed\n")
  cat("  3. Verify the URL is accessible\n")
  cat("  4. Review error messages above\n")
}

# ============================================================================
# SECTION 5: TROUBLESHOOTING GUIDE
# ============================================================================

# If the script fails, try these steps:
#
# 1. CHECK FIREFOX INSTALLATION
#    - Open Firefox manually to confirm it works
#    - Note: Chrome can also be used (change rsDriver browser parameter)
#
# 2. TEST CSS SELECTORS MANUALLY
#    - Open https://www.straitstimes.com/business in Firefox
#    - Press F12 to open DevTools
#    - Go to Console tab
#    - Test: document.querySelectorAll("YOUR_SELECTOR")
#    - Should return array of article elements
#
# 3. CHECK PORT AVAILABILITY
#    - If port 4567 is busy, change to 4568L or 4569L in initializeDriver()
#
# 4. VERBOSE MODE FOR DEBUGGING
#    - Set verbose = TRUE in rsDriver() call (line 59)
#    - More detailed error messages will appear
#
# 5. NETWORK ISSUES
#    - Ensure you can access Straits Times manually
#    - Check if site requires VPN/specific location
#
# 6. GECKODRIVER ISSUES
#    - First run downloads geckodriver automatically
#    - If fails, manually download from:
#      https://github.com/mozilla/geckodriver/releases
#    - Place in system PATH
#
# ============================================================================
# NEXT STEPS (AFTER STRAITS TIMES WORKS)
# ============================================================================

# Once this script works successfully:
# 1. Create similar scrapers for CNA and Business Times
# 2. Combine all scraped data with RSS feeds (Google News, Yahoo Finance)
# 3. Merge into unified dataset for sentiment analysis
# 4. Proceed to 03_clean_text.R

cat("\n✓ Script execution complete\n")
cat("Waiting for CSS selectors from manual testing...\n\n")

# ============================================================================
# CSS SELECTOR INPUT TEMPLATE (FOR YOU TO FILL IN)
# ============================================================================

# After testing in Firefox DevTools, replace the PLACEHOLDER selectors above:
#
# Site: Straits Times Business
# URL tested: https://www.straitstimes.com/business
# Date tested: _______________
#
# Article container: ".____________________"
# Headline: "._______________________"
# Link: "._________________________"
# Date: ".___________________________"
# Snippet: ".______________________"
#
# Notes/observations:
# - Are links absolute or relative? _______________
# - Date format? _______________
# - Any lazy-loading behavior? _______________
# - Number of articles visible after 3 scrolls? _______________
#
# Test command used in Console:
# document.querySelectorAll("YOUR_CONTAINER_SELECTOR").length
# Expected result: _____ articles
#