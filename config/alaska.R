# Manuscript study settings. The old shared csm.R default of 0.65 also affected
# Alaska callers; this explicit 0.80 profile follows the Methods chapter.
analysis_config <- list(
  region = "alaska", start_year = 1994L, end_year = 2023L,
  index_start_year = 1960L, availability = 0.80, significance = 0.10,
  temperature_multiplier = 2.5, rainy_day_threshold = 2,
  precipitation_normalization = "mean",
  station_list = "alaska/list.txt", station_list_separator = ",",
  station_directory = "alaska/stations", output_directory = "outputs/alaska",
  index_correlation_variables = c("tmax", "tmin"),
  rainy_day_correlation_variables = c("tmax", "tmin", "tmean"),
  indices = list(pdo = list(file = "alaska/indices/pdo.txt", separator = ",",
                            seasonal_p_value_digits = 2L)))
