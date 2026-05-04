# EXECUTION PLAN

## Purpose
Track implementation sequencing for the cyber-macro-impact-pilot MVP.

## Current status snapshot (as of 2026-05-04, commit 5581586)
1. Repository setup, documentation, and remote sync are complete.
2. End-to-end pipeline scripts `01` to `05` are implemented and runnable.
3. Incremental WDI ingestion is operational.
4. Incidents ingestion is operational using the World Bank annex source.
5. Cyber-primary model selection guard is implemented in model specs.
6. GCI 2024 tier ingestion is operational via ITU API slug `global-cybersecurity-index-2024`; tier midpoints are mapped to a 0-100 scale.
7. GCI 2020 score/rank backfill is operational via ITU API slug `d-str-gci.01-2021-htm-e`; the parser extracts raw 0-100 scores from the score/rank table.
8. GCI interpolation is implemented in `R/03_build_panel.R`: it fills 2021-2023 between 2020 and 2024 anchors, carries 2020 backward to earlier panel years, and carries 2024 forward to later panel years. `gci_overall_imputed` flags all derived rows.
9. WDI regional and income-group aggregates are filtered before panel construction. The current panel has 2696 rows, 224 country or territory codes, and covers 2014-2025.
10. Harmonisation audit output now reports dropped aggregate rows and true duplicate variable keys. Current audit: `wdi_non_country_rows_dropped = 4416`, `duplicate_variable_keys_remaining = 0`.
11. Report artifacts, figures, and model tables have been regenerated from the cleaned panel and rendered successfully to `report.html`.
12. Quarto execution defaults now hide chunk source in the rendered report, and the report narrative now explains significance markers and the weak incident-model results.
13. The last full repo-wide cleanup pass was committed and pushed to `origin/main` at `5581586 Clean panel inputs and refresh report`.
14. Phase 3 implementation is in progress locally: country metadata, compact report tables, GCI QA output, heterogeneity models, and a comparison coefficient figure have been generated but not yet committed.

## Phase 2 status (COMPLETED)
All phase 2 objectives are satisfied.

### 1) Incidents data quality hardening - DONE
- Schema validation checks added.
- Duplicate and outlier diagnostics by country-year added.
- Source provenance metadata fields added.
- QA output table for pre/post-cleaning row counts included.

### 2) Modeling robustness and interpretation - DONE
- Cyber incidents retained as primary regressor.
- Sensitivity run with `gci_overall` alternate cyber regressor implemented and active.
- Minimum sample thresholds and sparse-panel warnings in place.
- Narrative language kept explicitly associational throughout.

### 3) Data coverage expansion - DONE
- GCI 2024 and 2020 editions ingested from two ITU API slugs.
- GCI harmonized to country-year with interpolation and carry logic plus source labels.
- Side-by-side regressor comparison block active in `R/04_model_specs.R`.

### 4) Reproducibility and release readiness - DONE
- One-command run instructions documented for scripts `01` to `05` and report render.
- Expected-output checklist in README.
- Clean rerun confirmed from documented steps.
- Rendered report no longer exposes R chunk source in HTML output.

## What was completed in the latest cleanup pass
1. Filtered non-country WDI aggregates from harmonisation and rebuilt the panel.
2. Corrected the audit metric so duplicate reporting matches the actual long-format key.
3. Clarified GCI interpolation and carry assumptions in code, report text, and research notes.
4. Updated the dynamic trend figure so missing recent-series points are omitted cleanly rather than producing plot warnings.
5. Marked report rendering complete in README.
6. Hid code chunks in Quarto output by default and added an explicit significance guide to the report.
7. Regenerated report tables, figures, and `report.html`, then committed and pushed the cleaned state.

## What was completed in the current phase 3 pass
1. Added a World Bank country metadata refresh to `R/01_download_open_data.R`, writing `data_raw/wdi/wdi_country_metadata.csv`.
2. Joined country metadata into the processed panel in `R/03_build_panel.R`, adding `wb_region`, `income_group`, `income_group_model`, and `lending_type`.
3. Added compact model output CSVs for headline, robustness, and incidents-vs-readiness models.
4. Added GCI observed/derived coverage QA output at `output/tables/gci_imputation_qa.csv`.
5. Added income-group heterogeneity models using fixed buckets: `High income`, `Upper middle income`, and pooled `Lower income`.
6. Added a comparison coefficient plot at `output/figures/comparison_coefficients.png`.
7. Updated `report.qmd` to use compact tables, include GCI QA, include income-group heterogeneity, and include the coefficient plot.

## Immediate next execution plan (phase 3)
1. Finish validating the phase 3 outputs and commit the current generated artifacts.
2. Harden GCI scale consistency beyond coverage transparency.
3. Expand readiness regressor coverage beyond GCI.
4. Continue publication-readiness improvements.

### 1) GCI scale consistency
1. Investigate whether 2020 raw scores and 2024 tier midpoints can be harmonized analytically or should remain a documented limitation only.
2. Consider normalizing both editions to a common 0-1 range to reduce inter-edition scale noise.
3. Keep the new GCI QA table in the report and add an explicit sensitivity bound or normalized-scale variant before using GCI as a headline readiness estimate.

### 2) Additional readiness regressors
1. Evaluate GTMI or NCSI for time-series compatibility.
2. If a compatible source is found, ingest it and add it to the panel with transparent transformation rules.
3. Extend the comparison block with a third readiness regressor if coverage is defensible.

### 3) Model robustness and publication readiness
1. Review the new coefficient plot and compact tables for readability in `report.html`.
2. Summarize the income-group heterogeneity results in narrative form, including the 11 codes without income-group metadata.
3. Add session info or `renv` lock validation to the runbook or CI path.

## Definition of done for phase 3
- GCI scale caveat is either addressed analytically or bounded clearly in sensitivity analysis.
- At least one additional readiness index is evaluated for inclusion, even if rejected with written reasoning.
- A coefficient plot for the readiness comparison is included in the report.
- Heterogeneity check results are documented using fixed World Bank income-group splits, with unmatched metadata coverage called out explicitly.
- Pipeline reruns cleanly and outputs are committed.

## Current blockers and risks
- GCI has only two observed anchor years, so most annual readiness values are derived rather than observed.
- Scale inconsistency between GCI editions remains unresolved.
- Incident counts are disclosure-dependent and may mix underlying exposure with reporting intensity.
- Headline incident coefficients remain weak; some readiness results are statistically stronger but are more assumption-heavy.
- The current phase 3 changes are uncommitted and need a final review before push.
- World Bank country metadata leaves 11 panel country/territory codes without an income-group bucket.

## Decision log (latest first)
1. Committed and pushed the cleaned repository state to `origin/main` at `5581586`.
2. Hid Quarto chunk source by default and added significance guidance to the report text.
3. Filtered WDI regional and income-group aggregates from harmonisation; audit now reports dropped aggregate rows and true duplicate variable keys.
4. Switched the comparison model block to lagged `l1_gci_overall` two-way FE with explicit scale caveat documentation.
5. Implemented GCI interpolation between 2020 and 2024 anchors with carry-backward and carry-forward rules plus `gci_overall_imputed`.
6. Ingested GCI from two ITU API slugs with separate parsers for 2024 tier data and 2020 score/rank data.
7. Activated incidents-based cyber-primary runs using annex-derived country-year incidents.
8. Blocked silent fallback to non-cyber regressors unless explicitly enabled.
9. Enforced cyber-first regressor selection in model specs.
