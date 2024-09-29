# Both temperature/index and temperature/rainy-day comparisons use this entry point.
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L || !arguments[2] %in% c("indices", "rainy_days")) {
  stop("Usage: Rscript --vanilla scripts/index_correlations.R config/high_mountain_asia.R indices|rainy_days")
}
project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(project_root, "R", "io.R"))
configure_project_temp(project_root)
for (module in c("quality_control", "aggregation", "trends", "stations", "teleconnections")) {
  source(file.path(project_root, "R", paste0(module, ".R")))
}
source(resolve_input_path(project_root, arguments[1]))
data_root <- Sys.getenv("THESIS_DATA_ROOT", unset = "data")
result <- run_station_correlations(analysis_config, data_root, arguments[2])
output <- resolve_output_path(project_root, file.path(
  analysis_config$output_directory, paste0("station_", arguments[2], "_correlations.csv")))
write_csv(result, output, project_root = project_root)
message("Wrote ", output)
