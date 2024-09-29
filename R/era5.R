# ERA5 raster calculations retain the original serial loops and terra backend.
# No input is read and no raster processing begins when this file is sourced.

# Convert positional monthly accumulation blocks to last-minus-first values.
# Input units are preserved. The original precipitation file used two layers
# per month; this is not a general converter for arbitrary ERA5 hourly files.
era5_monthly_accumulation_differences <- function(
    values, years = 30L, months_per_year = 3L, layers_per_month = 2L) {
  month_indices <- seq_len(years * months_per_year)
  vapply(month_indices, function(month_index) {
    last_layer <- layers_per_month * month_index
    first_layer <- last_layer - layers_per_month + 1L
    values[last_layer] - values[first_layer]
  }, numeric(1))
}

# Relative precipitation trend (% per positional year), matching era5_prec.R.
# Means deliberately retain NA values. The denominator is the mean of the
# monthly differences, before seasonal aggregation.
era5_precipitation_slope <- function(
    values, years = 30L, months_per_year = 3L, layers_per_month = 2L) {
  monthly_values <- era5_monthly_accumulation_differences(
    values, years, months_per_year, layers_per_month
  )
  seasonal_means <- vapply(seq_len(years), function(year_index) {
    last_month <- months_per_year * year_index
    first_month <- last_month - months_per_year + 1L
    mean(monthly_values[first_month:last_month])
  }, numeric(1)) * 100 / mean(monthly_values)
  wql::mannKen(seasonal_means)$sen.slope
}

# Count supplied precipitation layers > 0.002 m by their timestamp year.
# The caller must supply daily totals for a count to mean rainy days. This
# preserves the raw slope actually stored by era5_rainy_days.R (days/year),
# including sum(...), without na.rm or a 00:00 timestamp shift.
# mannKen uses annual-series positions; absent whole years are not padded.
era5_rainy_day_slope <- function(values, timestamps) {
  calendar_years <- format(as.Date(timestamps), "%Y")
  rainy_values <- ifelse(values > 0.002, 1, 0)
  yearly_counts <- vapply(split(rainy_values, calendar_years), sum, numeric(1))
  wql::mannKen(yearly_counts)$sen.slope
}

# Annual means of supplied radiation layers; slope retains the input units
# per year. No accumulation conversion or relative normalization is added:
# both were absent from the active era5_radiation.R calculation.
# As in the original, missing whole years do not add empty positions.
era5_radiation_slope <- function(values, timestamps) {
  calendar_years <- format(as.Date(timestamps), "%Y")
  yearly_means <- vapply(split(values, calendar_years), mean, numeric(1))
  wql::mannKen(yearly_means)$sen.slope
}

# Apply an explicit series statistic to each row/column of a terra array.
# This retains the serial per-pixel algorithm used in the original scripts.
era5_grid_slopes <- function(raster_array, series_statistic) {
  row_count <- dim(raster_array)[1L]
  column_count <- dim(raster_array)[2L]
  slopes <- matrix(NA_real_, nrow = row_count, ncol = column_count)
  for (row_index in seq_len(row_count)) {
    for (column_index in seq_len(column_count)) {
      slopes[row_index, column_index] <- series_statistic(
        raster_array[row_index, column_index, ]
      )
    }
  }
  slopes
}

# Read one supplied GRIB/NetCDF raster and return a SpatRaster of slopes.
# study_period is recorded in configuration but is not a new temporal filter:
# original precipitation indexing is positional, and rainy/radiation grouping
# uses every supplied timestamp. Supply a file containing the intended period
# and season; no input is downloaded, selected by month, or rewritten here.
era5_trend_raster <- function(input_file, configuration) {
  input_raster <- terra::rast(input_file)
  raster_array <- as.array(input_raster)
  timestamps <- terra::time(input_raster)

  series_statistic <- switch(configuration$analysis,
    precipitation = {
      required_layers <- configuration$years * configuration$months_per_year *
        configuration$layers_per_month
      if (dim(raster_array)[3L] < required_layers) {
        stop("Precipitation input has fewer layers than the configured positional blocks.")
      }
      function(values) era5_precipitation_slope(
        values, configuration$years, configuration$months_per_year,
        configuration$layers_per_month
      )
    },
    rainy_days = function(values) era5_rainy_day_slope(values, timestamps),
    radiation = function(values) era5_radiation_slope(values, timestamps),
    stop("analysis must be precipitation, rainy_days, or radiation.")
  )
  slope_matrix <- era5_grid_slopes(raster_array, series_statistic)
  terra::rast(
    slope_matrix, ext = terra::ext(input_raster), crs = terra::crs(input_raster)
  )
}
