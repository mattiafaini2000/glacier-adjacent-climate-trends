# Climate trends near Alaskan and Asian glaciers

R analysis code supporting Mattia Faini's 2024 BSc thesis in Physics at the University of Milan, **“Observed Cooling Trends on Maximum Air Temperature Close to the Alaskan and Asian Glaciers in the Last Decades”**. The thesis supervisor is **Prof. Franco Salerno**; the co-supervisor is **Prof. Maurizio Maugeri**. The manuscript records academic year 2023–2024.

The [thesis manuscript (PDF)](observed_cooling_trends_near_glaciers.pdf) is stored using Git LFS.

The research examines maximum and minimum air temperature near glaciers in Alaska and Canada and in High Mountain Asia, particularly Karakoram and the Himalaya. Station observations, precipitation and rainy-day series, teleconnection indices, selected hourly precipitation records, and ERA5-Land reanalysis are used to investigate local cooling and its relationship to regional climate variability.

The primary station period is 1994–2023; index and temperature/rainy-day comparisons also include 1960–2023. The regional configurations state the study periods, availability thresholds, index files, and output locations explicitly. Analytical differences and input assumptions are described in [docs/workflows.md](docs/workflows.md).

## Main findings

During 1994–2023, station records showed summer maximum-temperature cooling in coastal and interior Alaska. Coastal Alaska's maximum temperature was positively associated with the Pacific Decadal Oscillation (PDO), whose recent trend was negative; the interior cooling lacked the same PDO association. Coastal precipitation and rainy days increased, and rainy days were negatively correlated with maximum temperature across the study region. The thesis interprets the coastal patterns primarily in terms of regional weather variability, cloud effects and cool air accompanying disturbances.

In High Mountain Asia, the thesis identifies Himalayan areas with summer maximum-temperature cooling and drying, discussed in relation to glacier-induced katabatic winds, and cooling of maximum and, at some stations, minimum temperature in Karakoram. Karakoram's summer maximum temperature correlated negatively with the Atlantic Multidecadal Oscillation (AMO) and positively with the Interdecadal Pacific Oscillation (IPO) during 1994–2023; most of these associations were not significant over 1960–2023. Rainy days increased despite little evidence for rising station precipitation totals. Their negative associations with maximum temperature suggest that weather disturbances may also contribute to the cooling.

ERA5-Land broadly supported the station temperature patterns and showed increasing summer snowfall in several cooling areas, particularly Karakoram. The thesis proposes that disturbances bringing cooler air could explain this snowfall–temperature association. Wind trends diverging from glaciers also leave open a contribution from katabatic winds. These associations do not establish a causal mechanism: reanalysis pixels span roughly 9 km, cooling and wind patterns extend far beyond glacier margins, and altered winds may be a response to cooling as well as a possible cause.

## Repository contents

| Location | Contents |
| --- | --- |
| `R/` | Functions for input/output paths, station preparation, filtering, aggregation, statistics, hourly analysis, ERA5 calculations, and plotting |
| `scripts/` | Five entry points for station trends, correlations, hourly precipitation, ERA5 trends, and selected figures |
| `config/` | Alaska and High Mountain Asia settings, plus hourly, ERA5, and figure configurations |
| `outputs/` | Generated tables, rasters, and figures; excluded from Git |

Reusable modules define functions without loading observations, opening graphics devices, or processing rasters when sourced.

## R dependencies

Station statistics require `wql`, alongside base and recommended R functions. Hourly analysis additionally requires `dplyr`. ERA5 calculations require `terra`; figure rendering requires `ggplot2`. [dependencies.csv](dependencies.csv) lists the package requirements by workflow.

No package versions are pinned, and no package-version compatibility is asserted. There is no dependency installer or automatic data download.

## Inputs and example commands

Run commands from the repository root with the required packages already available. `THESIS_DATA_ROOT` defaults to `data/` and may identify an external read-only input directory. Paths in the configuration files are relative to that root; outputs are relative to this repository. Create `.cache/tmp/` and set `TMPDIR`, `TMP`, and `TEMP` to its absolute path before starting R so that R's startup temporary files also stay inside the project. Entry points direct subsequent temporary and raster files into the project cache.

Daily inputs are station CSV files with `STATION`, `DATE`, `LATITUDE`, `LONGITUDE`, and the required `TMAX`, `TMIN`, or `PRCP` fields. Temperature and precipitation fields use the tenths-of-unit convention consumed by the code. Each regional workflow also requires a station list. Index comparisons require year-by-month index tables. Hourly inputs require the extracted station schema described in the workflow notes; ERA5 inputs require the specific layer ordering and temporal interpretation documented there.

These examples require the inputs described in [docs/workflows.md](docs/workflows.md) and the selected configuration:

```sh
Rscript --vanilla scripts/station_trends.R config/alaska.R temperature
Rscript --vanilla scripts/station_trends.R config/alaska.R rainy_days
Rscript --vanilla scripts/station_trends.R config/high_mountain_asia.R precipitation
Rscript --vanilla scripts/index_correlations.R config/high_mountain_asia.R indices
Rscript --vanilla scripts/index_correlations.R config/alaska.R rainy_days
Rscript --vanilla scripts/hourly_precipitation.R config/hourly.R
Rscript --vanilla scripts/era5_trends.R config/era5.R
Rscript --vanilla scripts/make_figures.R config/figures.R
```

The figure command consumes previously generated hourly tables. Its optional Arctic monthly plot additionally needs the regional station list and the station temperature and rainy-day trend tables. The default ERA5 configuration selects the positional precipitation calculation; it does not select years or months from an arbitrary raster.

## Outputs

Station tables are written to `outputs/alaska/` and `outputs/high_mountain_asia/`, with named fields for the station, variable, month or season, period, slope or correlation, p-value, and availability. Hourly station and pooled tables go to `outputs/hourly/`. ERA5 outputs go to `outputs/era5/`, and selected JPEG figures go to `outputs/figures/`. File outputs are checked to remain inside the repository.
