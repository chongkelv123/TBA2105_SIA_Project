# 03_scrape_prices.R
# Purpose: Download stock prices for SIA and validation tickers
# Author: Kelvin Chong
# Date: 2025-11-02

library(tidyverse)
library(quantmod)
library(lubridate)
library(arrow)

# Configuration -----------------------------------------------------------

# Stock tickers
TICKERS <- c(
  "C6L.SI",      # Singapore Airlines
  "0293.HK",     # Cathay Pacific
  "DAL",         # Delta Airlines  
  "9202.T"       # ANA (All Nippon Airways)
  # Note: Lufthansa (LHA.DE) removed - German exchange has data issues
)

# Macro variables
MACRO_TICKERS <- c(
  "BZ=F",        # Brent Crude Oil
  "DX-Y.NYB",    # USD Index
  "^VIX",        # VIX Volatility Index
  "^STI"         # Singapore Straits Times Index
)

# Date range: 2 years back
DATE_START <- Sys.Date() - years(2)
DATE_END <- Sys.Date()

OUTPUT_DIR <- "data_interim"
dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Functions ---------------------------------------------------------------

download_ticker <- function(ticker) {
  cat(sprintf("Downloading %s...\n", ticker))
  
  tryCatch({
    # Download data
    data <- getSymbols(
      ticker, 
      src = "yahoo", 
      from = DATE_START, 
      to = DATE_END, 
      auto.assign = FALSE
    )
    
    # Convert to tibble
    df <- data %>%
      as.data.frame() %>%
      rownames_to_column("date") %>%
      as_tibble() %>%
      mutate(
        date = ymd(date),
        ticker = ticker
      )
    
    # Standardize column names (remove ticker prefix)
    colnames(df) <- str_replace_all(
      colnames(df), 
      paste0("^", str_replace_all(ticker, "([\\^\\-\\=])", "\\\\\\1"), "\\."), 
      ""
    )
    
    # Ensure standard column names
    if ("Adjusted" %in% colnames(df)) {
      df <- df %>% rename(Adj.Close = Adjusted)
    }
    
    cat(sprintf("  ✓ %d days of data\n", nrow(df)))
    return(df)
    
  }, error = function(e) {
    warning(sprintf("  ✗ Error: %s\n", e$message))
    return(tibble())
  })
}

# Main Execution ----------------------------------------------------------

cat("========================================\n")
cat("DOWNLOADING STOCK PRICES\n")
cat("========================================\n")
cat("Date range:", format(DATE_START, "%Y-%m-%d"), "to", format(DATE_END, "%Y-%m-%d"), "\n")
cat("========================================\n\n")

# Download stock prices
cat("--- Stock Prices ---\n")
stock_prices <- map_dfr(TICKERS, download_ticker)

Sys.sleep(2)

# Download macro variables
cat("\n--- Macro Variables ---\n")
macro_prices <- map_dfr(MACRO_TICKERS, download_ticker)

# Save results (BOTH FORMATS)
if (nrow(stock_prices) > 0) {
  write_parquet(stock_prices, file.path(OUTPUT_DIR, "prices_stocks.parquet"))
  write_csv(stock_prices, file.path(OUTPUT_DIR, "prices_stocks.csv"))
}

if (nrow(macro_prices) > 0) {
  write_parquet(macro_prices, file.path(OUTPUT_DIR, "prices_macro.parquet"))
  write_csv(macro_prices, file.path(OUTPUT_DIR, "prices_macro.csv"))
}

cat("\n========================================\n")
cat("RESULTS SAVED (DUAL FORMAT)\n")
cat("========================================\n")
cat(sprintf("Stock prices: %d observations (%d tickers)\n", 
            nrow(stock_prices), 
            n_distinct(stock_prices$ticker)))
cat(sprintf("Macro prices: %d observations (%d variables)\n", 
            nrow(macro_prices), 
            n_distinct(macro_prices$ticker)))

# Summary by ticker
cat("\n--- Stock Price Coverage ---\n")
stock_prices %>%
  group_by(ticker) %>%
  summarise(
    first_date = min(date),
    last_date = max(date),
    days = n()
  ) %>%
  print()

cat("\n--- Macro Variable Coverage ---\n")
macro_prices %>%
  group_by(ticker) %>%
  summarise(
    first_date = min(date),
    last_date = max(date),
    days = n()
  ) %>%
  print()

cat("\n========================================\n")
cat("✓ Price download complete!\n")
cat("========================================\n")