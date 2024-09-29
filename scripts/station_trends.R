# Run from the repository root; argument 2 selects an implemented measurement group.
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 2L || !arguments[2] %in% c("temperature", "precipitation", "rainy_days")) {
  stop("Usage: Rscript --vanilla scripts/station_trends.R config/alaska.R temperature|precipitation|rainy_days")
}
project_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(project_root, "R", "io.R"))
configure_project_temp(project_root)
for (module in c("quality_control", "aggregation", "trends", "stations")) {
  source(file.path(project_root, "R", paste0(module, ".R")))
}
source(resolve_input_path(project_root, arguments[1]))
data_root <- Sys.getenv("THESIS_DATA_ROOT", unset = "data")
variables <- switch(arguments[2], temperature = c("tmax", "tmin", "tmean"),
                    precipitation = "precipitation", rainy_days = "rainy_days")
result <- run_station_trends(analysis_config, data_root, variables)
output <- resolve_output_path(project_root, file.path(
  analysis_config$output_directory, paste0("station_", arguments[2], "_trends.csv")))
write_csv(result, output, project_root = project_root)
message("Wrote ", output)
