# Read an extracted GHCN-hourly station table. Precipitation remains in mm.
read_hourly_observations <- function(file) {
  observations <- utils::read.csv(file, header = TRUE, fill = TRUE, sep = ",",
                                 colClasses = c(Station_ID = "character"),
                                 stringsAsFactors = FALSE)
  required <- c("Station_ID", "Station_name", "Latitude", "Longitude",
                "Year", "Month", "Day", "Hour", "Minute", "precipitation")
  missing_columns <- setdiff(required, names(observations))
  if (length(missing_columns)) {
    stop("Missing hourly columns: ", paste(missing_columns, collapse = ", "))
  }
  if (!nrow(observations)) stop("Empty hourly table: ", file)
  observations
}

# Keep every tie at the largest minute within a calendar hour, as in top_n(1).
# years gives explicit bounds; the original scripts only applied a lower bound.
select_hourly_observations <- function(observations, years, month = 8L,
                                       last_minute = TRUE) {
  selected <- dplyr::filter(observations, Month == month,
                            Year >= min(years), Year <= max(years))
  if (last_minute) {
    selected <- dplyr::group_by(selected, Year, Month, Day, Hour)
    selected <- dplyr::top_n(selected, 1L, Minute)
    selected <- dplyr::ungroup(selected)
  }
  selected
}

# Mean precipitation by UTC hour, across the selected daily observations.
hourly_precipitation_means <- function(selected) {
  grouped <- dplyr::group_by(selected, Hour)
  dplyr::summarise(grouped,
                   mean_precipitation_mm = mean(precipitation, na.rm = TRUE),
                   .groups = "drop")
}

# Annual August means are kept in calendar order, without filling missing years.
hourly_annual_means <- function(selected) {
  grouped <- dplyr::group_by(selected, Year, Hour)
  dplyr::summarise(grouped,
                   mean_precipitation_mm = mean(precipitation, na.rm = TRUE),
                   .groups = "drop")
}

# wql receives successive available annual means, matching hourly_trend.R.
# A gap in calendar years therefore remains a limitation of this implementation.
hourly_precipitation_trends <- function(annual_means) {
  hours <- sort(unique(annual_means$Hour))
  results <- lapply(hours, function(hour) {
    hour_means <- annual_means[annual_means$Hour == hour, , drop = FALSE]
    hour_means <- hour_means[order(hour_means$Year), , drop = FALSE]
    fit <- wql::mannKen(hour_means$mean_precipitation_mm)
    data.frame(Hour = hour, sen_slope = fit$sen.slope, p_value = fit$p.value)
  })
  dplyr::bind_rows(results)
}

# Average station annual means first, multiply by the 31 days of August, then
# estimate the trend. This differs from averaging separate station slopes.
pooled_hourly_precipitation <- function(station_annual_means,
                                        days_in_month = 31L) {
  combined <- dplyr::bind_rows(station_annual_means)
  combined$mean_precipitation_mm <- combined$mean_precipitation_mm * days_in_month
  grouped <- dplyr::group_by(combined, Year, Hour)
  annual_means <- dplyr::summarise(
    grouped, mean_precipitation_mm = mean(mean_precipitation_mm, na.rm = TRUE),
    .groups = "drop"
  )
  list(annual_means = annual_means,
       trends = hourly_precipitation_trends(annual_means))
}

# Calculate one station's tables without writing files or opening plot devices.
analyse_hourly_station <- function(file, years = 1994:2023, month = 8L,
                                   last_minute = TRUE) {
  observations <- read_hourly_observations(file)
  selected <- select_hourly_observations(observations, years, month, last_minute)
  if (!nrow(selected)) stop("No hourly observations in the configured window: ", file)
  station <- observations[1L, c("Station_ID", "Station_name", "Latitude", "Longitude"),
                          drop = FALSE]
  means <- hourly_precipitation_means(selected)
  annual_means <- hourly_annual_means(selected)
  trends <- hourly_precipitation_trends(annual_means)
  add_station <- function(values) {
    cbind(station[rep(1L, nrow(values)), , drop = FALSE], values,
          row.names = NULL)
  }
  means$mean_precipitation_mm <- round(means$mean_precipitation_mm, 4L)
  trends$sen_slope <- round(trends$sen_slope, 6L)
  list(means = add_station(means), annual_means = add_station(annual_means),
       trends = add_station(trends))
}
