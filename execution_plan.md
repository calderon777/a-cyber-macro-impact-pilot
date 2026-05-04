# EXECUTION PLAN

## Purpose
Track implementation sequencing for the cyber-macro-impact-pilot MVP.

## Current status snapshot (as of 2026-05-04, commit d094225)
1. Repository setup, documentation, and remote sync are complete.
2. End-to-end pipeline scripts 01-05 are implemented and runnable.
3. Incremental WDI ingestion is operational.
4. Incidents ingestion is now operational using the World Bank annex source.
5. Cyber-primary model selection guard is implemented in model specs.
6. Report artifacts (tables, figures, report HTML) are generated and committed.
7. **GCI 2024 tier ingestion** is operational via ITU API slug `global-cybersecurity-index-2024`; tier midpoints mapped to 0–100 scale (97.5/90/70/37.5/10).
8. **GCI 2020 score/rank backfill** is operational via ITU API slug `d-str-gci.01-2021-htm-e`; parses `<table id="table010">` for raw 0–100 scores. 386 rows in `data_raw/itu/gci_country_year.csv`.
9. **GCI interpolation** is implemented in `R/03_build_panel.R` via `gci_interpolate()`: linearly fills 2021–2023 between 2020/2024 anchors, carries backward to 2014–2019, and forward to 2025. `gci_overall_imputed` flag marks non-anchor rows.
10. **Comparison model block** updated in `R/04_model_specs.R` to use `l1_gci_overall` (lagged two-way FE, ~1517 obs) alongside `l1_cyber_incidents_log` (~860 obs).
11. Panel: 2696 rows, 224 country/territory codes, years 2014–2025, wide format, `data_processed/panel_country_year.parquet`; World Bank regional and income-group aggregates are filtered before panel construction.
12. Report and `deep-research-report.md` updated with interpolation policy, scale caveat (2020 raw vs 2024 tier midpoints), and shared lagged FE framing.

## Phase 2 status (COMPLETED)
All phase 2 objectives are satisfied.

### 1) Incidents data quality hardening — DONE (prior commits)
- ✅ Schema validation checks added.
- ✅ Duplicate and outlier diagnostics by country-year added.
- ✅ Source provenance metadata fields added.
- ✅ QA output table for pre/post-cleaning row counts included.

### 2) Modeling robustness and interpretation — DONE
- ✅ Cyber incidents retained as primary regressor.
- ✅ Sensitivity run with `gci_overall` alternate cyber regressor implemented and active.
- ✅ Minimum sample thresholds and sparse-panel warnings in place.
- ✅ Narrative language kept explicitly associational throughout.

### 3) Data coverage expansion — DONE (commit d094225)
- ✅ GCI 2024 and 2020 editions ingested from two ITU API slugs.
- ✅ GCI harmonized to country-year with interpolation/carry logic and source labels.
- ✅ Side-by-side regressor comparison block active in `R/04_model_specs.R`.

### 4) Reproducibility and release readiness — DONE (prior commits)
- ✅ One-command run instructions documented for scripts 01-05 and report render.
- ✅ Expected-output checklist in README.
- ✅ Clean rerun confirmed from documented steps.

## Immediate next execution plan (phase 3)
1. Harden GCI scale consistency and imputation transparency.
2. Expand readiness regressor coverage beyond GCI.
3. Extend model robustness and publication-readiness.

### 1) GCI scale consistency
1. Investigate whether 2020 raw scores (0–100) and 2024 tier midpoints can be reliably harmonised or should be reported as a known limitation only.
2. Consider normalising both editions to a common 0–1 range to reduce inter-edition scale noise.
3. Add a dedicated QA table showing anchor vs imputed rows per country in the report.

### 2) Additional readiness regressors
1. Evaluate GTMI (Government Technology Maturity Index) or NCSI (National Cyber Security Index) for time-series compatibility.
2. If a compatible source is found, ingest and add to panel with `gci_interpolate()` pattern.
3. Include in comparison block as a third alternate cyber regressor column.

### 3) Model robustness and publication readiness
1. Add coefficient plot for GCI comparison model to `R/05_figures.R`.
2. Add heterogeneity check: run models separately for high-income vs lower-income country groups.
3. Confirm all model tables render correctly in Quarto HTML and PDF outputs.
4. Add session info / `renv` lock validation step to CI or runbook.

## Definition of done for phase 3
- GCI scale caveat is either resolved analytically or documented with a sensitivity bound.
- At least one additional readiness index is evaluated for inclusion (even if rejected with reasoning).
- Coefficient plot for GCI alternate model is in the report.
- Heterogeneity check results are documented.
- Pipeline reruns cleanly and all outputs are committed.

## Current blockers and risks
- GCI has only two anchor years (2020, 2024); interpolated values in 2021–2023 are synthetic and should not be over-interpreted.
- Scale inconsistency between GCI editions (raw 0–100 vs tier midpoints) is a known limitation flagged in the report.
- Incident counts are disclosure-dependent and can mix signal with reporting intensity.
- Cross-source methodological changes can create comparability breaks across years.

## Decision log (latest)
1. Enforced cyber-first regressor selection in model specs.
2. Blocked silent fallback to non-cyber regressors unless explicitly enabled.
3. Activated incidents-based cyber-primary run using annex-derived country-year incidents.
4. Ingested GCI from two ITU API slugs with separate parsers for 2024 (tier) and 2020 (raw score).
5. Implemented linear interpolation between 2020/2024 GCI anchors with carry-backward/forward and `gci_overall_imputed` flag column.
6. Switched comparison model block to `l1_gci_overall` lagged two-way FE; scale caveat documented in report.
7. Filtered WDI regional and income-group aggregates from harmonisation; audit now reports dropped aggregate rows and true duplicate variable keys.
