# Workflow reference

All entry points are run from the repository root. Regional files define `analysis_config`; hourly and figure files define `hourly_config` and `figures_config`. `THESIS_DATA_ROOT` defaults to `data/`. Input files may be read from an external root, while output and processing-cache paths stay inside the project. Set R's startup temporary-directory environment variables as described in the README. No workflow downloads inputs.

**Station inputs and methods**

Regional lists contain headerless station IDs in the first column, with their delimiter specified in configuration. Identifiers are read as text. Daily CSVs require `STATION`, `DATE`, `LATITUDE`, `LONGITUDE`, plus the measurement columns needed for the selected analysis. `DATE` must be readable by `as.Date`; invalid dates produce an input error. The code divides numeric `TMAX` and `TMIN` by 10 to obtain degrees Celsius, and `PRCP` by 10 to obtain millimetres. It adds no interpretation of observation quality flags or undocumented missing-value sentinels.

Temperature filtering groups all supplied observations by calendar month, across years. The accepted range is inclusive: Q10 − 2.5 × (Q90 − Q10) through Q90 + 2.5 × (Q90 − Q10). Filtering precedes study-window selection, so the supplied observation sample affects the quantiles. Precipitation outside 0–10000 mm is missing; both endpoints are retained.

Monthly availability must be **strictly greater** than the fixed month length multiplied by the regional threshold. February has 28 days even in leap years. Temperature uses the available daily mean. Precipitation totals and rainy-day counts are expanded by `month_length / n_available`. A rainy day requires precipitation **strictly greater than 2 mm** in the supplied profiles. The correlation path retains its separately implemented order, `mean(rainy_flags) * month_length`, whereas the trend path uses `sum(rainy_flags) * (month_length / n_available)`.

Seasonal values are arithmetic means of all three constituent monthly values, with missing months propagating to a missing season. DJF is assigned to January/February's year and includes December of the preceding year. Precipitation seasons are means of monthly totals, not seasonal sums. Seasonal Tmean is `(seasonal Tmax + seasonal Tmin) / 2`; it is supported for temperature trends and rainy-day comparisons, rather than as a new daily or monthly temperature series.

Sen slopes and Mann–Kendall p-values use `wql::mannKen`, retaining missing calendar-year positions in station matrices. The recent station window is 1994–2023; correlations additionally use 1960–2023. Period availability is also a strict inequality. Pearson correlations use available pairs: index eligibility checks temperature availability, while rainy-day eligibility checks paired availability. Fewer than three pairs returns missing statistics. Significance uses the raw p-value and the configured threshold, normally 0.10.

Set `precipitation_normalization = "mean"` for percentage slopes or `"none"` for absolute precipitation/rainy-day slopes. Percentage series are normalized **before** fitting as `values * 100 / mean(values, na.rm = TRUE)`. Each monthly or seasonal series supplies its own denominator. The manuscript describes normalization using monthly means; the seasonal percentage implementation instead uses the mean of the selected seasonal series, which is retained. No imputation, detrending, or significance correction is applied in these workflows.

Station trend outputs contain `id`, coordinates, `variable`, `aggregation`, `period`, year bounds, `n_available`, `mean`, `sen_slope`, `p_value`, `significant`, `reported_p_value`, and `units`. Reported means are missing when period availability fails. Slopes and correlations are rounded to three decimals. Raw p-values are separate from the two-decimal presentation retained for seasonal percentage, rainy-day correlation, and multi-index variants. Temperature and NAO p-values retain their unrounded presentation. Correlation outputs also name `comparator` and `n_pairs`. Unused difference columns and ambiguous MAX/MIN/S block labels are replaced by explicit fields.

**Indices and preparation**

Prepared index files have a header, a first column of calendar years, and twelve numeric monthly columns in January–December order. Most use commas; the configured NAO table uses whitespace. Values with absolute magnitude greater than 90 are missing. Alaska uses PDO. High Mountain Asia lists NINO3.4, AO, EUR, AMO, PDO, IPO, IOD, and NAO explicitly. Index and station matrices are joined by declared calendar years.

`R/preparation.R` provides geographic/record-span inventory selection and Pyramid conversion. The inventory selection uses strict geographic bounds and record-length inequalities; it does not establish daily completeness. Pyramid input is a semicolon table with year/month/day followed by Tmin/Tmean/Tmax/precipitation in physical units, converted to the shared tenths-of-unit schema. These helpers return objects and do not run an extraction workflow.

**Hourly precipitation and figures**

The hourly configuration requires separate station and pooled-coastal ID lists plus comma-delimited `hourly_extracted/<ID>.txt` files. Required columns are `Station_ID`, `Station_name`, `Latitude`, `Longitude`, `Year`, `Month`, `Day`, `Hour`, `Minute`, and `precipitation`. Precipitation is used unchanged in millimetres; the manuscript identifies hours as UTC.

The configured window is August 1994–2023. Every tie at the largest minute within a calendar hour is retained, matching `dplyr::top_n`. Means omit missing measurements. Annual means are fitted separately by hour without inserting absent years; a per-year slope interpretation assumes consecutive annual rows. No additional completeness gate is imposed. Station means are reported to four decimals and station slopes to six. The pooled workflow multiplies each station's annual August mean by 31, averages over stations by year/hour, then estimates the slope. This aggregation order differs from averaging separate station slopes.

`outputs/hourly/` contains `station_means.csv`, `station_annual_means.csv`, `station_trends.csv`, `pooled_annual_means.csv`, and `pooled_trends.csv`. Annual tables name `Year` and `Hour`; statistical tables name slope and raw p-value. The pooled annual field `mean_precipitation_mm` includes the 31-day scaling. No absent hour is filled to force a 24-column output.

The figure entry point renders station hourly means and the pooled trend chart. Filled bars indicate p < 0.10 on the pooled trend chart; station mean plots have no significance test. It reads the saved four-decimal mean table, a presentation precision difference from plotting unrounded means directly. Set `figures_config$regional_monthly = TRUE` to render the optional Arctic monthly plot after supplying `alaska/arctic.csv` and generating temperature/rainy-day trend tables. This plot averages station slopes, preserves duplicate list weighting, and uses `sd / sqrt(n_available)` for Tmax error bars. Its fixed 10:1 secondary axis requires rainy-day slopes in percent/year; absolute-unit tables are rejected. Many map and comparison figures need missing GIS layers or intermediate tables. The Gilgit hourly figure is attributed to Franco Salerno in the manuscript and has no supplied standalone reconstruction workflow.

**ERA5 inputs and implemented behavior**

The ERA5 entry point retains the serial `terra` implementation and full raster-array traversal. Its configuration selects `precipitation`, `rainy_days`, or `radiation`, one input, and one output. `study_period` records the intended supplied interval; it does **not** filter raster years or months. Inputs must already contain the intended period and season.

Precipitation uses 30 positional years × three months × two accumulation layers per month. Each monthly value is the last minus the first layer in its pair. Three monthly values are averaged, multiplied by `100 / mean(all monthly differences)`, and passed to `wql::mannKen`. Missing values propagate; no unit conversion is added. Exact hours and season cannot be established without the missing raster/request metadata. This pairing is not a general ERA5 deaccumulation method.

Rainy-day analysis compares layers strictly above 0.002 metres, sums by timestamp year, and stores the **raw** slope. Daily totals are required to interpret layer counts as days. Radiation takes annual means of supplied layers and also stores the raw slope, in input units per annual position. Neither adds missing-year padding or removes missing layer values. The manuscript explains that 00:00 UTC accumulation belongs to the previous day; these implementations do not shift that timestamp or perform a general accumulation conversion. The precipitation pairing is retained separately. The manuscript's percentage-map descriptions do not override the active raw-slope assignments.

**Correspondence to the thesis**

| Workflow | Manuscript sections |
| --- | --- |
| Station filtering, monthly/seasonal aggregation, statistics | Methods: “Outliers filters”, “Means computation and handling of missing data”, “Trends and Correlations” |
| Alaska temperature, PDO, rainfall, and regional figures | Results and Discussion: Alaska and Canada |
| HMA temperature, AMO/IPO and other indices, rainfall comparisons | Results and Discussion: High Mountain Asia, through Karakoram Stations Analysis |
| Hourly precipitation | Alaska “Hourly Precipitation Data Analysis” |
| ERA5 precipitation, rainy days, and radiation | HMA “Era5-Land Analysis” and supplementary material; precise figure reconstruction depends on unavailable inputs |

Station data are attributed in Methods to NOAA GHCN, with additional HMA records from researchers; hourly Alaska records to GHCN-hourly; indices to NOAA; reanalysis to the Copernicus Climate Data Store. Exact downloads, permissions, and request specifications are absent. The QGIS ZIP projects, station metadata, and LaTeX manuscript source remain unchanged local references. The thesis PDF is available through Git LFS.
