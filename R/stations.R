# GHCN-style daily CSV: DATE, STATION, LATITUDE, LONGITUDE, TMAX/TMIN/PRCP.
# Original scripts divide all three measurement columns by 10 (Celsius or mm).
read_daily_station <- function(file) {
  station <- utils::read.csv(file, header = TRUE, fill = TRUE, sep = ",",
                            colClasses = c(STATION = "character"),
                            stringsAsFactors = FALSE)
  required <- c("DATE", "STATION", "LATITUDE", "LONGITUDE")
  if (!all(required %in% names(station))) {
    stop("Missing station metadata columns in ", file)
  }
  station$DATE <- as.Date(station$DATE)
  if (anyNA(station$DATE)) stop("Missing or invalid DATE values in ", file)
  station
}

# Headerless station list: IDs in the first column; extra columns are ignored.
read_station_ids <- function(file, separator = ",") {
  station_list <- utils::read.table(file, header = FALSE, fill = TRUE,
                                  sep = separator, colClasses = "character")
  station_list[[1]]
}

# Return monthly and seasonal matrices without running trends or writing files.
# Filtering uses all supplied daily observations, as in the original scripts.
# Matrices end at config$end_year, and retain December before the study period.
prepare_station_series <- function(station, config, rainy_day_statistic = "rainy_days") {
  dates <- station$DATE
  series <- list()
  for (measurement in c("TMAX", "TMIN")) {
    if (measurement %in% names(station)) {
      values <- filter_temperature(as.numeric(station[[measurement]]) / 10,
                                   dates, config$temperature_multiplier)
      series[[tolower(measurement)]] <- aggregate_daily_months(
        dates, values, config$availability, "mean")
    }
  }
  if ("PRCP" %in% names(station)) {
    precipitation <- filter_precipitation(as.numeric(station$PRCP) / 10)
    series$precipitation <- aggregate_daily_months(
      dates, precipitation, config$availability, "precipitation")
    series$rainy_days <- aggregate_daily_months(
      dates, precipitation, config$availability, rainy_day_statistic, config$rainy_day_threshold)
  }
  start_year <- min(as.integer(format(dates, "%Y")), config$index_start_year)
  monthly <- lapply(series, complete_years, start_year = start_year,
                    end_year = config$end_year)
  seasonal <- lapply(monthly, seasonal_means)
  # Tmean variants compute the arithmetic mean after seasonal aggregation;
  # this requires both Tmax and Tmin, and is not a daily mean-temperature series.
  if (all(c("tmax", "tmin") %in% names(monthly))) {
    seasonal$tmean <- (seasonal$tmax + seasonal$tmin) / 2
  }
  list(monthly = monthly, seasonal = seasonal)
}

station_identity <- function(station) {
  data.frame(id = as.character(station$STATION[1]),
             latitude = station$LATITUDE[1], longitude = station$LONGITUDE[1],
             stringsAsFactors = FALSE)
}

# One row per station, variable and calendar month/season. Means retain units of
# monthly aggregates; relative slopes are percent per year, never percent totals.
station_trend_rows <- function(station, config, variables) {
  prepared <- prepare_station_series(station, config)
  years <- seq.int(config$start_year, config$end_year)
  rows <- list()
  for (aggregation in names(prepared)) {
    for (variable in intersect(variables, names(prepared[[aggregation]]))) {
      values <- prepared[[aggregation]][[variable]][as.character(years), , drop = FALSE]
      water_variable <- variable %in% c("precipitation", "rainy_days")
      normalization <- match.arg(config$precipitation_normalization, c("mean", "none"))
      relative <- water_variable && normalization == "mean"
      for (period in colnames(values)) {
        trend <- estimate_station_trend(values[, period], config$availability,
                                         relative, config$significance)
        # Percentage seasonal scripts reported p-values to two decimals;
        # the raw value is retained separately for significance and inspection.
        trend$reported_p_value <- if (relative && aggregation == "seasonal") {
          round(trend$p_value, 2)
        } else trend$p_value
        row <- cbind(station_identity(station), data.frame(
          variable = variable, aggregation = aggregation, period = period,
          year_start = min(years), year_end = max(years),
          as.data.frame(trend),
          units = if (relative) "percent/year" else switch(
            variable, precipitation = "mm/year", rainy_days = "days/year", "degC/year"),
          stringsAsFactors = FALSE))
        rows[[length(rows) + 1L]] <- row
      }
    }
  }
  if (!length(rows)) stop("No requested measurement columns in station input.")
  do.call(rbind, rows)
}

run_station_trends <- function(config, data_root, variables) {
  list_file <- resolve_input_path(data_root, config$station_list)
  station_ids <- read_station_ids(list_file, config$station_list_separator)
  rows <- lapply(station_ids, function(station_id) {
    station_file <- resolve_input_path(
      data_root, file.path(config$station_directory, paste0(station_id, ".csv")))
    station_trend_rows(read_daily_station(station_file), config, variables)
  })
  do.call(rbind, rows)
}
