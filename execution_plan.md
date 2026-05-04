# EXECUTION PLAN

## Purpose
Track implementation sequencing for the cyber-macro-impact-pilot MVP.

## Current status snapshot (as of 2026-05-04, commit 58e73b0)
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
13. The full repo-wide cleanup pass was committed and pushed to `origin/main` at `5581586 Clean panel inputs and refresh report`.
14. The phase 3 heterogeneity and reporting pass was committed and pushed to `origin/main` at `58e73b0 Implement phase 3 heterogeneity and report outputs`.
15. Phase 3 core outputs are now in version control: country metadata integration, compact model tables, GCI imputation QA, heterogeneity regressions, and the comparison coefficient figure.
16. A normalized readiness sensitivity pathway is now implemented locally and validated: `gci_overall_norm` (within-edition percentile anchors in 2020/2024 with interpolation/carry), plus `l1_gci_overall_norm` comparison and heterogeneity estimates.

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

## What was completed in the latest phase 3 commit (`58e73b0`)
1. Added a World Bank country metadata refresh to `R/01_download_open_data.R`, writing `data_raw/wdi/wdi_country_metadata.csv`.
2. Joined country metadata into the processed panel in `R/03_build_panel.R`, adding `wb_region`, `income_group`, `income_group_model`, and `lending_type`.
3. Added compact model output CSVs for headline, robustness, and incidents-vs-readiness models.
4. Added GCI observed/derived coverage QA output at `output/tables/gci_imputation_qa.csv`.
5. Added income-group heterogeneity models using fixed buckets: `High income`, `Upper middle income`, and pooled `Lower income`.
6. Added a comparison coefficient plot at `output/figures/comparison_coefficients.png`.
7. Updated `report.qmd` to use compact tables, include GCI QA, include income-group heterogeneity, and include the coefficient plot.

## Immediate next execution plan (phase 3)
1. Finalize interpretation of the GCI scale-sensitivity pathway and document the bound explicitly.
2. Expand readiness regressor coverage beyond GCI.
3. Continue publication-readiness improvements.

### 1) GCI scale consistency
1. Investigate whether 2020 raw scores and 2024 tier midpoints can be harmonized analytically or should remain a documented limitation only.
2. Compare level-scale (`l1_gci_overall`) and percentile-normalized (`l1_gci_overall_norm`) readiness results and state whether conclusions are directionally stable.
3. Keep the GCI QA table in the report and add an explicit sensitivity-bound statement before using GCI as a headline readiness estimate.

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
- Scale inconsistency between GCI editions is partially bounded by the new normalized sensitivity pathway but remains unresolved conceptually.
- Incident counts are disclosure-dependent and may mix underlying exposure with reporting intensity.
- Headline incident coefficients remain weak; some readiness results are statistically stronger but are more assumption-heavy.
- World Bank country metadata leaves 11 panel country/territory codes without an income-group bucket.

## Decision log (latest first)
1. Implemented and validated a normalized GCI sensitivity path: `gci_overall_norm` in panel construction, `l1_gci_overall_norm` in comparison and heterogeneity models, and updated readiness coefficient figure/report filters.
2. Committed and pushed the phase 3 heterogeneity and report-output pass to `origin/main` at `58e73b0`.
3. Committed and pushed the cleaned repository state to `origin/main` at `5581586`.
4. Hid Quarto chunk source by default and added significance guidance to the report text.
5. Filtered WDI regional and income-group aggregates from harmonisation; audit now reports dropped aggregate rows and true duplicate variable keys.
6. Switched the comparison model block to lagged `l1_gci_overall` two-way FE with explicit scale caveat documentation.
7. Implemented GCI interpolation between 2020 and 2024 anchors with carry-backward and carry-forward rules plus `gci_overall_imputed`.
8. Ingested GCI from two ITU API slugs with separate parsers for 2024 tier data and 2020 score/rank data.
9. Activated incidents-based cyber-primary runs using annex-derived country-year incidents.
10. Blocked silent fallback to non-cyber regressors unless explicitly enabled.
11. Enforced cyber-first regressor selection in model specs.
