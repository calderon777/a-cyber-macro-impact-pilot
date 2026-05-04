# EXECUTION PLAN

## Purpose
Track implementation sequencing for the cyber-macro-impact-pilot MVP.

## Current status snapshot
1. Repository setup, documentation, and remote sync are complete.
2. End-to-end pipeline scripts 01-05 are implemented and runnable.
3. Incremental WDI ingestion is operational.
4. Incidents ingestion is now operational using the World Bank annex source.
5. Cyber-primary model selection guard is implemented in model specs.
6. Report artifacts (tables, figures, report HTML) are generated and committed.

## Immediate next execution plan (phase 2)
1. Stabilize incidents data pipeline quality.
2. Improve model identification and interpretation discipline.
3. Expand cyber regressor coverage beyond incidents.
4. Harden reproducibility checks and publish runbook updates.

### 1) Incidents data quality hardening
1. Add schema validation checks for incidents input columns and value ranges.
2. Add duplicate and outlier diagnostics by country-year.
3. Add source provenance metadata fields (source URL, extraction date, transform rule).
4. Add a small QA output table for pre/post-cleaning row counts by year.

### 2) Modeling robustness and interpretation
1. Keep cyber incidents as primary regressor while incidents are available.
2. Add sensitivity run with alternate cyber regressor when available (for example gci_overall).
3. Add minimum sample thresholds and clear warnings when models run on sparse panels.
4. Update narrative language to keep baseline findings explicitly associational.

### 3) Data coverage expansion
1. Ingest at least one additional cyber readiness source (GCI or GTMI time-compatible slice).
2. Harmonize to country-year and include in panel with clear source labels.
3. Re-run model and figure pipeline with side-by-side regressor comparison.

### 4) Reproducibility and release readiness
1. Add one-command run instructions for scripts 01-05 and report render.
2. Add expected-output checklist to README and/or report preface.
3. Confirm clean rerun from a fresh clone using only documented steps.

## Definition of done for phase 2
- Incidents ingestion includes validation and QA summary outputs.
- At least one additional cyber regressor is integrated into panel construction.
- Headline and robustness tables include cyber-primary and at least one alternate cyber specification.
- Report text is updated to reflect final model set and interpretation limits.
- Pipeline reruns successfully from documented commands on a clean workspace.

## Current blockers and risks
- Readiness data (GCI/GTMI) may be low-frequency or not fully time-aligned with annual macro outcomes.
- Incident counts are disclosure-dependent and can mix signal with reporting intensity.
- Cross-source methodological changes can create comparability breaks across years.

## Decision log (latest)
1. Enforced cyber-first regressor selection in model specs.
2. Blocked silent fallback to non-cyber regressors unless explicitly enabled.
3. Activated incidents-based cyber-primary run using annex-derived country-year incidents.
