# OBJECTIVE

## Primary objective
Build a public, reproducible MVP repository that estimates associations between cyber capacity/risk proxies and macroeconomic outcomes using open country-year data.

## Starting point (from Workflow and code plan)
The first delivery target is a runnable pipeline that:
1. Downloads open macro and cyber-related datasets.
2. Harmonises country-year keys (ISO3 + numeric year).
3. Produces a merged panel dataset and a variable dictionary.
4. Runs a compact baseline set of fixed-effects models.
5. Renders one report with one headline table and two figures.

## MVP scope
- Public/open data only for baseline reproducibility.
- Optional private cyber-spend inputs only via local file checks.
- Keep analysis concise and transparent (roughly 200 lines of analysis code in report).

## Deliverables
- `report.qmd`
- `data_processed/panel_country_year.parquet`
- `data_processed/data_dictionary.csv`
- `output/tables/` and `output/figures/`
- `README.md`

## Related planning document
Implementation sequencing and operational tasks are tracked in `execution_plan.md`.
