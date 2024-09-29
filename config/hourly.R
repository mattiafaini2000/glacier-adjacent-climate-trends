hourly_config <- list(
  station_list = "alaska/hourly_buone.txt",
  pooled_station_list = "alaska/hourly_buone_S.txt",
  observations_dir = "alaska/hourly_extracted",
  years = 1994:2023,
  month = 8L,
  last_minute = TRUE,
  days_in_month = 31L,
  significance = 0.10,
  output_dir = "outputs/hourly"
)
