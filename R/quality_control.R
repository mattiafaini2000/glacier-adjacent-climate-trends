# Filter daily temperature in degrees Celsius by calendar month, across years.
# Values on the Q10/Q90 bounds are retained, as in csm.R and the Methods chapter.
filter_temperature <- function(values, dates, multiplier = 2.5) {
  month <- format(dates, "%m")
  filtered <- values
  for (month_name in unique(month)) {
    indices <- which(month == month_name)
    quantiles <- stats::quantile(values[indices], c(0.1, 0.9), na.rm = TRUE)
    spread <- quantiles[2] - quantiles[1]
    outside <- values[indices] < quantiles[1] - multiplier * spread |
      values[indices] > quantiles[2] + multiplier * spread
    filtered[indices[which(outside)]] <- NA_real_
  }
  filtered
}

# Preserve the original precipitation bounds after conversion to millimetres.
filter_precipitation <- function(values, lower = 0, upper = 10000) {
  values[which(values < lower | values > upper)] <- NA_real_
  values
}
