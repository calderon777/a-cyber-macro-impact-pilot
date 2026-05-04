# Cyber Macro Impact Pilot

## Objective
Build a public, reproducible MVP that evaluates how cyber capacity and incident intensity relate to macroeconomic outcomes in a country-year panel.

See OBJECTIVE.md for the execution scope and phase-based definition of done.

## Repository layout

- data_raw/: raw source files by provider
- data_processed/: merged panel and variable dictionary
- R/: data and analysis scripts
- output/: generated tables and figures
- report.qmd: analysis report

## Quick start

1. Open the project in VS Code.
2. Run R/00_packages.R to install packages.
3. Run scripts in numeric order:
	- R/01_download_open_data.R
	- R/02_clean_harmonise.R
	- R/03_build_panel.R
	- R/04_model_specs.R
	- R/05_figures.R
4. Render report.qmd.

Optional incidents input:

- Set `INCIDENTS_CSV_URL` before running `R/01_download_open_data.R` to ingest an open country-year incidents CSV.
- Or place a local file at `data_raw/incidents/incidents_source.csv`.
- Required logical fields: country ISO3 (or country name), year, and incident count.
- The pipeline will create `cyber_incidents` and `cyber_incidents_log` automatically.

## Reproducibility & Environment Validation

The pipeline is designed for reproducibility across environments:

- **R version & packages:** Run `R/00_packages.R` once to install required packages into your local R library. The script uses base R functionality and standard CRAN packages (dplyr, fixest, ggplot2, arrow, etc.) with minimal version constraints.
- **Session info:** After running the full pipeline, execute `sessionInfo()` in the R console to capture your environment. Compare against prior runs to verify consistency.
- **Data reproducibility:** Each script logs input/output rows and refresh timestamps. Check log files in `data_raw/*/` for audit trails (e.g., `data_raw/wdi/wdi_refresh_log.csv`, `data_raw/itu/gci_refresh_log.csv`).
- **Clean re-run:** To verify end-to-end reproducibility from scratch: delete all `data_processed/` and `output/` directories, clear the R environment, and re-run scripts 01-05 in order. The panel dimensions and summary statistics should match prior runs.

Note: GCI values for 2021-2023 are interpolated from 2020 and 2024 anchors, so these years are synthetic. See the report and code comments for full interpolation assumptions.

## Current status

- [x] Project scaffold created
- [x] Data download and harmonisation implemented
- [x] Baseline FE models implemented
- [x] Report fully rendered with results
