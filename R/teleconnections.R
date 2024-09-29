# Original index tables: header, first column calendar year, then 12 months.
# Separator varies: comma for most prepared tables, whitespace for the NAO table.
# Values with abs(value) > 90 are missing, preserving the original index rule.
read_monthly_index <- function(file, separator, end_year, start_year = 1960) {
  monthly <- as.matrix(utils::read.table(
    file, header = TRUE, fill = TRUE, row.names = 1, sep = separator))
  if (ncol(monthly) != 12L) stop("Index input requires 12 monthly columns: ", file)
  storage.mode(monthly) <- "numeric"
  monthly[abs(monthly) > 90] <- NA_real_
  colnames(monthly) <- month.abb
  complete_years(monthly, min(as.integer(rownames(monthly)), start_year), end_year)
}

# Explicit calendar-year alignment replaces the historical positional tail match.
# Both declared comparison windows are used; this is not claimed to reproduce
# the old Sys.Date()/31-row slicing numerically.
station_correlation_rows <- function(station, config, comparators, comparator_type) {
  # Correlation originals used mean(rainy flags) * month length, whereas trend
  # originals used sum(rainy flags) * (month length / available observations).
  prepared <- prepare_station_series(station, config, "rainy_day_frequency")
  if (comparator_type == "rainy_days") {
    if (!"rainy_days" %in% names(prepared$monthly)) {
      stop("Rainy-day correlations require PRCP.")
    }
    comparators <- list(rainy_days = list(
      monthly = prepared$monthly$rainy_days, seasonal = prepared$seasonal$rainy_days,
      seasonal_p_value_digits = 2L))
  }
  windows <- list(recent = seq.int(config$start_year, config$end_year),
                  long = seq.int(config$index_start_year, config$end_year))
  variables <- if (comparator_type == "rainy_days") {
    config$rainy_day_correlation_variables
  } else config$index_correlation_variables
  rows <- list()
  for (comparator_name in names(comparators)) {
    for (aggregation in names(prepared)) {
      for (variable in intersect(variables,
                                 names(prepared[[aggregation]]))) {
        for (window_name in names(windows)) {
          years <- windows[[window_name]]
          values <- prepared[[aggregation]][[variable]][as.character(years), , drop = FALSE]
          comparator <- comparators[[comparator_name]][[aggregation]][
            as.character(years), , drop = FALSE]
          for (period in colnames(values)) {
            correlation <- estimate_station_correlation(
              values[, period], comparator[, period], config$availability,
              gate = if (comparator_type == "rainy_days") "paired" else "temperature",
              significance = config$significance)
            digits <- comparators[[comparator_name]]$seasonal_p_value_digits
            correlation$reported_p_value <- if (aggregation == "seasonal" && !is.na(digits)) {
              round(correlation$p_value, digits)
            } else correlation$p_value
            rows[[length(rows) + 1L]] <- cbind(station_identity(station), data.frame(
              variable = variable, comparator = comparator_name,
              aggregation = aggregation, period = period,
              year_start = min(years), year_end = max(years),
              as.data.frame(correlation), stringsAsFactors = FALSE))
          }
        }
      }
    }
  }
  if (!length(rows)) stop("No temperature measurement columns in station input.")
  do.call(rbind, rows)
}

run_station_correlations <- function(config, data_root, comparator = "indices") {
  comparators <- list()
  if (comparator == "indices") {
    for (index_name in names(config$indices)) {
      specification <- config$indices[[index_name]]
      monthly <- read_monthly_index(
        resolve_input_path(data_root, specification$file), specification$separator,
        config$end_year, config$index_start_year)
      comparators[[index_name]] <- list(
        monthly = monthly, seasonal = seasonal_means(monthly),
        seasonal_p_value_digits = specification$seasonal_p_value_digits)
    }
  }
  station_ids <- read_station_ids(
    resolve_input_path(data_root, config$station_list), config$station_list_separator)
  rows <- lapply(station_ids, function(station_id) {
    station_file <- resolve_input_path(
      data_root, file.path(config$station_directory, paste0(station_id, ".csv")))
    station_correlation_rows(read_daily_station(station_file), config, comparators, comparator)
  })
  do.call(rbind, rows)
}
