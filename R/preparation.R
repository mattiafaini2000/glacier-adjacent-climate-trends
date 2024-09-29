# Select IDs from the six-column GHCN inventory export used by selection.R.
# Bounds and record-length inequalities are strict, as in the original script.
# This describes inventory coverage, not daily observation completeness.
select_station_inventory <- function(
    inventory, latitude_bounds = c(25, 50), longitude_bounds = c(65, 110),
    latest_year_after = 2022, record_span_over = 30) {
  if (ncol(inventory) < 6L) stop("Inventory needs at least six columns.")
  selected <- inventory[[2L]] > latitude_bounds[1L] &
    inventory[[2L]] < latitude_bounds[2L] &
    inventory[[3L]] > longitude_bounds[1L] &
    inventory[[3L]] < longitude_bounds[2L] &
    inventory[[6L]] > latest_year_after &
    inventory[[6L]] - inventory[[5L]] > record_span_over
  inventory[selected, 1L]
}

# Pyramid's semicolon-delimited daily source has year, month, day followed by
# TMIN, TMEAN, TMAX and PRCP. Temperatures are degrees C; precipitation is mm.
# Return the station CSV schema used by the daily workflows, in tenths of units.
prepare_pyramid_station <- function(observations) {
  if (ncol(observations) != 7L ||
      !all(c("year", "month", "day") %in% names(observations))) {
    stop("Pyramid input needs year/month/day and four measurement columns.")
  }
  dates <- as.Date(paste(observations$year, observations$month,
                         observations$day, sep = "-"))
  measurements <- observations[, -(1L:3L), drop = FALSE]
  names(measurements) <- c("TMIN", "TMEAN", "TMAX", "PRCP")
  data.frame(
    STATION = "pyramid", DATE = dates, LATITUDE = 27.96, LONGITUDE = 86.81,
    TMAX = as.numeric(measurements$TMAX) * 10,
    TMIN = as.numeric(measurements$TMIN) * 10,
    PRCP = as.numeric(measurements$PRCP) * 10,
    stringsAsFactors = FALSE
  )
}
