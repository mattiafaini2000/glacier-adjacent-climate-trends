# Example for the positional precipitation calculation in era5_prec.R.
# Supply the original-style GRIB file under THESIS_DATA_ROOT/era5/.
# This config does not establish its missing layer order or scientific metadata.
analysis_config <- list(
  analysis = "precipitation",
  input = "era5/precipitation.grib",
  output = "outputs/era5/precipitation_trend.tif",
  study_period = c(1994L, 2023L),
  years = 30L,
  months_per_year = 3L,
  layers_per_month = 2L
)

# Other supported configurations use analysis = "rainy_days" or "radiation"
# with their respective daily-total or radiation raster and a distinct output.
# The study_period labels the intended supplied data; it does not subset layers.
