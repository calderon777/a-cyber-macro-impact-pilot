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

## Current status

- [x] Project scaffold created
- [ ] Data download and harmonisation implemented
- [ ] Baseline FE models implemented
- [ ] Report fully rendered with results
