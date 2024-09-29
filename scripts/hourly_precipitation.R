# Run from the repository root: Rscript --vanilla scripts/hourly_precipitation.R config/hourly.R
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L) {
  stop("Usage: Rscript --vanilla scripts/hourly_precipitation.R config/hourly.R")
}
project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(project_root, "R", "io.R"))
configure_project_temp(project_root)
source(file.path(project_root, "R", "hourly.R"))
configuration <- new.env(parent = baseenv())
sys.source(resolve_input_path(project_root, arguments[1L]), envir = configuration)
hourly_config <- configuration$hourly_config
if (!is.list(hourly_config)) stop("Configuration must define hourly_config.")
data_root <- Sys.getenv("THESIS_DATA_ROOT", unset = file.path(project_root, "data"))
station_ids <- as.character(utils::read.table(
  resolve_input_path(data_root, hourly_config$station_list),
  header = FALSE, fill = TRUE, colClasses = "character"
)[, 1L])
pooled_station_ids <- as.character(utils::read.table(
  resolve_input_path(data_root, hourly_config$pooled_station_list),
  header = FALSE, fill = TRUE, colClasses = "character"
)[, 1L])
all_station_ids <- unique(c(station_ids, pooled_station_ids))
station_results <- lapply(all_station_ids, function(station_id) {
  file <- resolve_input_path(
    data_root, file.path(hourly_config$observations_dir, paste0(station_id, ".txt"))
  )
  analyse_hourly_station(file, hourly_config$years, hourly_config$month,
                         hourly_config$last_minute)
})
names(station_results) <- all_station_ids
station_means <- dplyr::bind_rows(lapply(station_results[station_ids], `[[`, "means"))
station_trends <- dplyr::bind_rows(lapply(station_results[station_ids], `[[`, "trends"))
station_annual_means <- dplyr::bind_rows(
  lapply(station_results[station_ids], `[[`, "annual_means")
)
pooled <- pooled_hourly_precipitation(
  lapply(station_results[pooled_station_ids], `[[`, "annual_means"),
  hourly_config$days_in_month
)
pooled$trends$significant <- pooled$trends$p_value < hourly_config$significance
for (result_name in c("station_means", "station_trends", "station_annual_means")) {
  write_csv(get(result_name),
            resolve_output_path(project_root, file.path(hourly_config$output_dir,
                                                       paste0(result_name, ".csv"))),
            project_root)
}
write_csv(pooled$annual_means,
          resolve_output_path(project_root, file.path(hourly_config$output_dir,
                                                     "pooled_annual_means.csv")), project_root)
write_csv(pooled$trends,
          resolve_output_path(project_root, file.path(hourly_config$output_dir,
                                                     "pooled_trends.csv")), project_root)
