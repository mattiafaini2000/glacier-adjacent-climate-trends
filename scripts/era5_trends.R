# Usage from the repository root:
# Rscript --vanilla scripts/era5_trends.R config/era5.R
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L) {
  stop("Usage: Rscript --vanilla scripts/era5_trends.R config/era5.R")
}
script_argument <- grep("^--file=", commandArgs(), value = TRUE)
script_file <- sub("^--file=", "", script_argument[1L])
project_root <- normalizePath(file.path(dirname(script_file), ".."), mustWork = TRUE)
source(file.path(project_root, "R", "io.R"))
configure_project_temp(project_root)
source(file.path(project_root, "R", "era5.R"))

configuration_file <- resolve_input_path(project_root, arguments[1L])
configuration_environment <- new.env(parent = baseenv())
sys.source(configuration_file, envir = configuration_environment)
configuration <- configuration_environment$analysis_config
data_root <- Sys.getenv("THESIS_DATA_ROOT", unset = file.path(project_root, "data"))

# terra may create processing files when inputs are larger than memory.
cache_directory <- resolve_output_path(project_root, ".cache/terra")
dir.create(cache_directory, recursive = TRUE, showWarnings = FALSE)
terra::terraOptions(tempdir = cache_directory)

input_file <- resolve_input_path(data_root, configuration$input)
output_file <- resolve_output_path(project_root, configuration$output)
dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
trend_raster <- era5_trend_raster(input_file, configuration)
terra::writeRaster(trend_raster, filename = output_file, overwrite = FALSE)
message("Wrote ", output_file)
