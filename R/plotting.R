# Return a precipitation bar chart; saving it is the caller's responsibility.
# values contains Hour and either mean_precipitation_mm or sen_slope.
plot_hourly_precipitation <- function(values, value_column, title, y_label,
                                      significance = NULL) {
  values$plotted_value <- values[[value_column]]
  if (is.null(significance)) {
    chart <- ggplot2::ggplot(values, ggplot2::aes(x = Hour, y = plotted_value)) +
      ggplot2::geom_col(fill = "skyblue", color = "black")
  } else {
    values$is_significant <- values$p_value < significance
    chart <- ggplot2::ggplot(
      values, ggplot2::aes(x = Hour, y = plotted_value, fill = is_significant)
    ) +
      ggplot2::geom_col(color = "black") +
      ggplot2::scale_fill_manual(values = c("TRUE" = "skyblue", "FALSE" = "white"),
                                 guide = "none")
  }
  chart + ggplot2::labs(title = title, x = "Hour of the Day (UTC)", y = y_label) +
    ggplot2::theme_minimal() +
    ggplot2::theme(plot.title = ggplot2::element_text(hjust = 0.5))
}

# Summarise the monthly slopes already estimated for individual stations.
# This is the mean of station slopes; it does not fit a trend to a regional mean.
# The Tmax error bar is sd / sqrt(number of non-missing station slopes).
regional_monthly_trends <- function(trends, station_ids, years,
                                    rainy_day_column = "sen_slope") {
  required <- c("id", "variable", "aggregation", "period", "year_start",
                "year_end", "sen_slope", "units", rainy_day_column)
  missing_columns <- setdiff(required, names(trends))
  if (length(missing_columns)) {
    stop("Missing station trend columns: ", paste(missing_columns, collapse = ", "))
  }
  selected <- trends[trends$aggregation == "monthly" &
                       trends$year_start == min(years) &
                       trends$year_end == max(years), , drop = FALSE]
  # The original Arctic figure included only stations in the rainy-day table.
  rainy_day_ids <- selected$id[selected$variable == "rainy_days"]
  included_ids <- station_ids[station_ids %in% rainy_day_ids]
  if (!length(included_ids)) stop("No configured stations have monthly rainy-day rows.")
  selected <- do.call(rbind, lapply(included_ids, function(station_id) {
    selected[selected$id == station_id, , drop = FALSE]
  }))
  if (any(selected$units[selected$variable == "rainy_days"] != "percent/year")) {
    stop("Regional figure requires rainy-day trends with percent/year units.")
  }
  monthly_values <- lapply(month.abb, function(month) {
    values <- selected[selected$period == month, , drop = FALSE]
    maximum <- values$sen_slope[values$variable == "tmax"]
    minimum <- values$sen_slope[values$variable == "tmin"]
    rainy_days <- values[[rainy_day_column]][values$variable == "rainy_days"]
    data.frame(month = month, tmax = mean(maximum, na.rm = TRUE),
               tmin = mean(minimum, na.rm = TRUE),
               rainy_days = mean(rainy_days, na.rm = TRUE),
               tmax_standard_error = stats::sd(maximum, na.rm = TRUE) /
                 sqrt(sum(!is.na(maximum))))
  })
  do.call(rbind, monthly_values)
}

# Preserve the Arctic figure's 10:1 axis scale and its fixed temperature limits.
plot_regional_monthly_trends <- function(monthly_trends, title) {
  monthly_trends$month <- factor(monthly_trends$month, levels = month.abb,
                                  labels = month.name)
  ggplot2::ggplot(monthly_trends, ggplot2::aes(x = month)) +
    ggplot2::geom_col(ggplot2::aes(y = rainy_days / 10, fill = "Rainy Days")) +
    ggplot2::geom_line(ggplot2::aes(y = tmax, color = "Max Temperature", group = 1)) +
    ggplot2::geom_line(ggplot2::aes(y = tmin, color = "Min Temperature", group = 1)) +
    ggplot2::geom_point(ggplot2::aes(y = tmax, color = "Max Temperature")) +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = tmax - tmax_standard_error,
                    ymax = tmax + tmax_standard_error, color = "Max Temperature"),
      width = 0.2
    ) +
    ggplot2::geom_point(ggplot2::aes(y = tmin, color = "Min Temperature")) +
    ggplot2::scale_x_discrete(limits = month.name) +
    ggplot2::scale_y_continuous(
      "Temperature Trend (degrees C/y)", limits = c(-0.165, 0.16),
      breaks = seq(-0.15, 0.15, by = 0.05),
      labels = function(value) sprintf("%.2f", value),
      sec.axis = ggplot2::sec_axis(~ . * 10, name = "Rainy Days Trend (%/y)")
    ) +
    ggplot2::scale_colour_manual(
      "", values = c("Max Temperature" = "red", "Min Temperature" = "blue")
    ) +
    ggplot2::scale_fill_manual("", values = c("Rainy Days" = "Aquamarine")) +
    ggplot2::labs(x = NULL, title = title) +
    ggplot2::theme(text = ggplot2::element_text(size = 15),
                     axis.text.x = ggplot2::element_text(angle = 90, hjust = 1),
                     legend.position = "bottom",
                     plot.title = ggplot2::element_text(hjust = 0.5))
}
