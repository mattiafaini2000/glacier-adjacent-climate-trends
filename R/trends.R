# Estimate a Sen slope with wql::mannKen, retaining missing calendar-year slots.
# Relative series are normalized BEFORE estimation, as in the percentage scripts.
# The slope is reported to three decimals; raw p-values are also returned.
estimate_station_trend <- function(values, availability, relative = FALSE,
                                   significance = 0.10) {
  series_mean <- mean(values, na.rm = TRUE)
  analysed <- if (relative) values * 100 / series_mean else values
  result <- list(
    n_available = sum(!is.na(analysed)), mean = NA_real_,
    sen_slope = NA_real_, p_value = NA_real_, significant = NA)
  if (result$n_available > length(values) * availability) {
    trend <- wql::mannKen(analysed)
    result$mean <- series_mean
    result$sen_slope <- round(trend$sen.slope, 3)
    result$p_value <- trend$p.value
    result$significant <- trend$p.value < significance
  }
  result
}

# Temperature/index scripts checked temperature availability; rainy-day
# correlation scripts checked paired availability. Keep this choice explicit.
estimate_station_correlation <- function(values, comparator, availability,
                                         gate = "paired", significance = 0.10) {
  paired <- stats::complete.cases(values, comparator)
  available <- sum(!is.na(values))
  pairs <- sum(paired)
  result <- list(n_available = available, n_pairs = pairs,
                 correlation = NA_real_, p_value = NA_real_, significant = NA)
  gate_count <- if (gate == "temperature") available else pairs
  if (gate_count > length(values) * availability && pairs >= 3L) {
    correlation <- stats::cor.test(values[paired], comparator[paired], method = "pearson")
    result$correlation <- round(unname(correlation$estimate), 3)
    result$p_value <- correlation$p.value
    result$significant <- correlation$p.value < significance
  }
  result
}
