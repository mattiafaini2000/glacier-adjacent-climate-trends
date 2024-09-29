# Run from the repository root: Rscript --vanilla scripts/make_figures.R config/figures.R
arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 1L) {
  stop("Usage: Rscript --vanilla scripts/make_figures.R config/figures.R")
}
project_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(project_root, "R", "io.R"))
configure_project_temp(project_root)
source(file.path(project_root, "R", "plotting.R"))
configuration <- new.env(parent = baseenv())
sys.source(resolve_input_path(project_root, arguments[1L]), envir = configuration)
figures_config <- configuration$figures_config
if (!is.list(figures_config)) stop("Configuration must define figures_config.")
period_label <- paste0(min(figures_config$hourly_years), "-",
                       max(figures_config$hourly_years))
station_means <- utils::read.csv(resolve_input_path(
  project_root, file.path(figures_config$hourly_output_dir, "station_means.csv")
), colClasses = c(Station_ID = "character"))
pooled_trends <- utils::read.csv(resolve_input_path(
  project_root, file.path(figures_config$hourly_output_dir, "pooled_trends.csv")
))
for (station_id in unique(station_means$Station_ID)) {
  values <- station_means[station_means$Station_ID == station_id, , drop = FALSE]
  figure <- plot_hourly_precipitation(
    values, "mean_precipitation_mm",
    paste0("Mean Precipitation by Hour in August (", period_label, ")\n",
           values$Station_name[1L]), "Precipitation (mm)"
  )
  destination <- resolve_output_path(
    project_root, file.path(figures_config$output_dir, paste0(station_id, "_hourly_mean.jpg"))
  )
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(destination, plot = figure, width = 12, height = 6, dpi = 200)
}
pooled_figure <- plot_hourly_precipitation(
  pooled_trends, "sen_slope",
  paste0("Precipitation by Hour Trend in August (", period_label, ")\n",
         "Coastal Stations Mean"), "Precipitation Trend (mm/y)",
  figures_config$significance
)
destination <- resolve_output_path(
  project_root, file.path(figures_config$output_dir, "hourly_trends_S.jpg")
)
dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
ggplot2::ggsave(destination, plot = pooled_figure, width = 12, height = 6, dpi = 200)
if (isTRUE(figures_config$regional_monthly)) {
  data_root <- Sys.getenv("THESIS_DATA_ROOT", unset = file.path(project_root, "data"))
  station_ids <- as.character(utils::read.table(
    resolve_input_path(data_root, figures_config$regional_station_list),
    header = FALSE, fill = TRUE, sep = ",", colClasses = "character"
  )[, 1L])
  temperature_trends <- utils::read.csv(
    resolve_input_path(project_root, figures_config$station_temperature_trends),
    colClasses = c(id = "character")
  )
  rainy_day_trends <- utils::read.csv(
    resolve_input_path(project_root, figures_config$station_rainy_days_trends),
    colClasses = c(id = "character")
  )
  trends <- rbind(temperature_trends, rainy_day_trends)
  monthly_trends <- regional_monthly_trends(
    trends, station_ids, figures_config$regional_years
  )
  write_csv(monthly_trends,
            resolve_output_path(project_root, file.path(figures_config$output_dir,
                                                       "arctic_monthly_summary.csv")),
            project_root)
  regional_figure <- plot_regional_monthly_trends(monthly_trends,
                                                  figures_config$regional_title)
  destination <- resolve_output_path(project_root,
                                     file.path(figures_config$output_dir, "arctic.jpg"))
  ggplot2::ggsave(destination, plot = regional_figure, width = 12, height = 6, dpi = 200)
}
