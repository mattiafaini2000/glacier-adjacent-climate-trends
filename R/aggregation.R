# Insert missing years as NA; the end year is explicit rather than Sys.Date().
# Input: numeric matrix with calendar years as row names. No imputation occurs.
complete_years <- function(values, start_year, end_year) {
  years <- seq.int(start_year, end_year)
  completed <- matrix(
    NA_real_, nrow = length(years), ncol = ncol(values),
    dimnames = list(as.character(years), colnames(values)))
  included <- rownames(values) %in% rownames(completed)
  completed[rownames(values)[included], ] <- values[included, , drop = FALSE]
  completed
}

# Original station convention: February has 28 days even in leap years.
# Available observations must be strictly greater than month_length * threshold.
# Precipitation totals and rainy-day counts are scaled to the fixed month length.
aggregate_daily_months <- function(dates, values, availability, statistic = "mean",
                                   rainy_day_threshold = 2) {
  month_lengths <- c(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)
  years <- sort(unique(as.integer(format(dates, "%Y"))))
  monthly <- matrix(
    NA_real_, nrow = length(years), ncol = 12,
    dimnames = list(as.character(years), month.abb))
  groups <- split(seq_along(dates), format(dates, "%Y-%m"))
  for (year_month in names(groups)) {
    year <- substr(year_month, 1, 4)
    month <- as.integer(substr(year_month, 6, 7))
    observations <- values[groups[[year_month]]]
    available <- sum(!is.na(observations))
    if (available > month_lengths[month] * availability) {
      expansion_factor <- month_lengths[month] / available
      monthly[year, month] <- switch(
        statistic,
        mean = mean(observations, na.rm = TRUE),
        precipitation = sum(observations, na.rm = TRUE) * expansion_factor,
        rainy_days = sum(observations > rainy_day_threshold, na.rm = TRUE) *
          expansion_factor,
        rainy_day_frequency = mean(observations > rainy_day_threshold, na.rm = TRUE) *
          month_lengths[month],
        stop("Unknown monthly statistic: ", statistic))
    }
  }
  monthly
}

# Standard seasonal means, including precipitation and rainy-day counts.
# DJF is assigned to the year of January/February. All three months are required.
# Consequently precipitation seasons are means of monthly totals, not sums.
seasonal_means <- function(monthly) {
  if (ncol(monthly) != 12L) stop("Seasonal means require 12 monthly columns.")
  seasonal <- matrix(
    NA_real_, nrow = nrow(monthly), ncol = 4,
    dimnames = list(rownames(monthly), c("DJF", "MAM", "JJA", "SON")))
  for (year_index in seq_len(nrow(monthly))) {
    if (year_index > 1L) {
      seasonal[year_index, "DJF"] <- mean(c(
        monthly[year_index - 1L, 12], monthly[year_index, 1:2]))
    }
    seasonal[year_index, "MAM"] <- mean(monthly[year_index, 3:5])
    seasonal[year_index, "JJA"] <- mean(monthly[year_index, 6:8])
    seasonal[year_index, "SON"] <- mean(monthly[year_index, 9:11])
  }
  seasonal
}
