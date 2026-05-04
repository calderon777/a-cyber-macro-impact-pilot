# Cyber Macro Impact Pilot: Source-Reviewed Research Note

## Executive summary

This note sets out a defensible, reproducible macroeconomic pilot on cyber risk and cyber investment proxies. The source base supports three conclusions.

Cyber incidents impose material economic costs, but aggregate loss estimates vary substantially across methods and reporting channels (Vergara Cobos & Cakir, 2024). Policy institutions identify structural underinvestment drivers, including externalities and information asymmetries (Kopp et al., 2017). Public cross-country data can support an open pilot, but most available indicators capture readiness, digital capability, or incident exposure rather than direct cyber spending (OECD, 2024; ITU, n.d.-a; ITU, n.d.-b).

Accordingly, the pilot should keep five constructs analytically separate:

1. Cyber spending (direct expenditure)
2. Cyber readiness/capability (institutional and policy capacity)
3. Incident exposure (event counts/intensity)
4. Cyber losses (economic damage)
5. Digital adoption/context (broader digitalization controls)

Baseline panel estimates should be interpreted as associational unless stronger identification is established.

## Literature synthesis

### What is well-supported in the current source spine

1. Economic costs are material, but measurement is fragmented. The World Bank review shows that estimates vary with definitions, reporting channels, and valuation methods (Vergara Cobos & Cakir, 2024).
2. Macro-financial policy relevance is conceptually strong. IMF analysis identifies market failures in cyber risk management consistent with a role for regulation and coordinated public action (Kopp et al., 2017).
3. Measurement strategy must be explicit. OECD guidance on cybersecurity measurement stresses multidimensional indicators and warns against one-dimensional proxying (OECD, 2024).

### What remains weak in the current source spine

1. Clean global causal estimates of country-year cyber spending on GDP are not established in the supplied evidence base.
2. Public, internationally comparable country-year cyber spending series are limited in open form.
3. Incident datasets are often disclosure-dependent; observed incidents should be treated as lower-bound exposure indicators.

### Working interpretation standard for this report

Use language such as associated with, consistent with, and suggests for baseline panel findings. Reserve causal claims for designs with explicit, testable identification assumptions.

## Data inventory

### Variable taxonomy for this pilot

1. Cyber spending: direct expenditures on cybersecurity goods/services (preferred but sparse in open data).
2. Cyber readiness: legal, institutional, governance, and capability indicators.
3. Incident exposure: country-year incident counts or rates.
4. Cyber losses: direct and indirect damage estimates (often heterogeneous and non-comparable).
5. Digital adoption/context: internet and digitalization controls used to reduce omitted-variable bias.

### Minimum open-data architecture

1. Macro outcomes and controls from World Development Indicators (World Bank, n.d.-a; World Bank, n.d.-b).
2. Cyber readiness and ICT context from ITU sources and related international indicators (ITU, n.d.-a; ITU, n.d.-b).
3. Incident exposure from open incident repositories (World Bank Annex, 2014-2022; CISSM; EuRepoC).
4. Productivity complements from Penn World Table (Feenstra et al., 2024).

## Empirical strategy

The baseline panel model remains:

$$
y_{it} = \beta C_{i,t-k} + \gamma'X_{i,t-k} + \alpha_i + \lambda_t + \varepsilon_{it}
$$

Definitions:

1. $y_{it}$: macro outcomes (for example GDP growth, productivity proxy, investment share, employment ratio)
2. $C_{i,t-k}$: one cyber family at a time (readiness, incidents, or optional spending)
3. $X_{i,t-k}$: controls (inflation, trade, population, and digital context)
4. $\alpha_i$: country fixed effects
5. $\lambda_t$: year fixed effects

Recommended estimation sequence:

1. Baseline FE with $k=1$ lag
2. Distributed-lag FE with $k=1,2,3$
3. Sensitivity checks with alternate cyber families and sample restrictions

Interpretation standard:

1. Treat baseline coefficients as conditional associations.
2. Flag directional evidence, not causal effect sizes, unless identification assumptions are explicitly tested.

### Current implementation note (May 2026)

The repository now reports two distinct comparison specifications and they should not be interpreted as equivalent estimands:

1. Incident exposure models use lagged terms (for example $l1\_cyber\_incidents\_log$) in country and year fixed-effects panel regressions.
2. GCI readiness models now also use lagged terms (for example $l1\_gci\_overall$) in country and year fixed-effects panel regressions. GCI values for years 2021-2023 are linearly interpolated between the 2020 edition (scores 0-100) and the 2024 edition (tier midpoints). Earlier panel years carry the 2020 value backward, later years carry the 2024 value forward, and the `gci_overall_imputed` flag column distinguishes observed anchor years from derived values.
3. When readiness data do not support two-way fixed effects (for example, too few observations after listwise deletion), the comparison pathway falls back to a time-FE or cross-section specification with heteroskedasticity-robust standard errors, depending on sample structure.

Practical implication: with interpolation and carry rules in place, both the incident and GCI columns in the comparison table share the same lagged two-way FE estimand, making coefficient magnitudes more directly comparable. These derived GCI values are a maintained approximation; directional interpretation is appropriate but causal ranking should remain cautious.

## Workflow and code plan

Use the existing repository pipeline:

1. `R/01_download_open_data.R`: refresh WDI and optional incidents source
2. `R/02_clean_harmonise.R`: normalize keys and schema
3. `R/03_build_panel.R`: produce panel and dictionary
4. `R/04_model_specs.R`: estimate FE and robustness models
5. `R/05_figures.R`: generate structural and dynamic charts
6. `report.qmd`: render reproducible narrative output

Operational policy:

1. Append new years where feasible rather than re-downloading full histories.
2. Preserve an audit trail for refreshes and harmonization outcomes.
3. Keep model outputs and rendered artifacts available for external review.

## Ready-to-use prompts for future automation

### Prompt 1: Literature extraction (source-disciplined)

```text
Read the attached cyber economics and policy sources.
Return a table with: source, year, design, sample, outcome, cyber variable, exact estimate, identification note, limitation.
Rules:
- Use only values explicitly present in sources.
- If numeric evidence is missing, write "not reported".
- Distinguish cyber spending, readiness, incident exposure, and cyber losses.
```

### Prompt 2: Data wrangling plan

```text
Build a country-year merge plan for the listed datasets.
Return:
1) canonical schema,
2) variable mapping,
3) duplicate-key checks,
4) missingness summary,
5) executable R code.
Rules:
- stop on invalid merge keys,
- do not silently drop observations,
- log dropped rows with reason.
```

### Prompt 3: Model generation

```text
Using panel_country_year.parquet, produce FE model scripts and a report section.
Requirements:
- country and year FE,
- clustered SE by country,
- lag helper (1-3 years),
- one headline and one robustness table,
- two figures (partial-correlation and dynamic trend/event-style fallback),
- cautious language for associational interpretation.
```

## Limitations

1. Direct country-year cyber spending remains sparse in open sources provided here.
2. Incident counts may reflect both true exposure and reporting/disclosure differences.
3. Readiness indicators and digital adoption indicators are related but not equivalent to spending.
4. Cross-source methodological breaks (coverage, definitions, and collection protocols) may reduce comparability.
5. GCI readiness values for 2021-2023 are linearly interpolated between the 2020 and 2024 edition anchor years, with 2020 carried backward to earlier panel years and 2024 carried forward to later panel years. The 2020 edition reports direct scores (0-100) while the 2024 edition reports tier midpoints (97.5 / 90 / 70 / 37.5 / 10); derived values span two different measurement scales, so absolute magnitudes should be interpreted with caution.

## Claims audit table

| claim | source | source location if available | confidence | action |
|---|---|---|---|---|
| Cyber incidents impose real economic costs, but aggregate estimates vary by method. | Vergara Cobos & Cakir (2024), World Bank | Executive summary and findings sections of report | high | keep |
| Measurement fragmentation is a core policy problem in cyber economics. | OECD (2024) | OECD Digital Economy Paper No. 366 | high | keep |
| Cyber risk can be underpriced due to market failures and externalities. | Kopp et al. (2017), IMF WP 17/185 | Conceptual framework sections | high | keep |
| Public country-year incident data exist for 2014-2022 via World Bank annex. | World Bank Annex (2014-2022) | Annex dataset page | high | keep |
| ITU provides cross-country cyber/ICT indicators suitable for readiness context. | ITU DataHub; ITU GCI; ITU IDI pages | Official ITU pages | high | keep |
| Penn World Table can support productivity-side macro outcomes. | Feenstra et al. (2024), PWT 11 | PWT documentation/site | high | keep |
| A specific global causal elasticity of cyber spending on GDP is established in this source set. | No direct evidence in supplied spine | N/A | low | remove |
| Any numeric claim not directly retrievable from cited source text/tables. | N/A | N/A | low | needs verification |
| Incident counts are equivalent to monetary cyber loss. | Conceptual contradiction across sources | N/A | low | remove |
| Readiness indices can proxy institutional capacity but are not direct spending measures. | OECD (2024); ITU sources; World Bank digital/governance sources | Methodology/discussion sections | high | keep |

## Data Sources Appendix

| dataset | organisation | URL | unit of observation | country coverage | year coverage | key variables | access method | main limitation | role in pilot |
|---|---|---|---|---|---|---|---|---|---|
| Indicators API documentation | World Bank | https://datahelpdesk.worldbank.org/knowledgebase/articles/889392-about-the-indicators-api-documentation | API metadata/spec | global | n/a (documentation) | API endpoints, parameters | web/API docs | not data itself | implementation guide |
| World Development Indicators | World Bank | https://databank.worldbank.org/source/world-development-indicators | country-year | global | multi-decade, variable-specific | GDP growth, employment/productivity proxies, inflation, trade, population | web/API | no direct cyber spending variable | macro outcomes and controls |
| Digital Adoption Index | World Bank | https://www.worldbank.org/en/publication/wdr2016/Digital-Adoption-Index | country-(wave) | broad global | limited waves | digital adoption sub-indices | web download | sparse time frequency | digital context baseline |
| GovTech Maturity Index | World Bank | https://www.worldbank.org/en/programs/govtech/gtmi | country-(wave) | broad global | periodic waves | govtech maturity pillars | web download | low-frequency, partly self-reported | institutional digital readiness proxy |
| GovTech Dataset | World Bank | https://datacatalog.worldbank.org/search/dataset/0037889/govtech-dataset | country-(wave) | broad global | periodic waves | governance/digital public sector indicators | data catalog download | sparse panel | structural controls/proxy |
| ITU DataHub | ITU | https://datahub.itu.int/ | country-year/series | broad global | series-dependent | ICT/cyber-related indicators | portal/API export where available | indicator definitions vary by series | cyber/ICT context and readiness |
| ICT Development Index (IDI) | ITU | https://www.itu.int/en/ITU-D/Statistics/Pages/IDI/default.aspx | country-(edition) | broad global | edition-based | ICT development composite | web publication | methodological discontinuities across editions | digital capability context |
| Global Cybersecurity Index (GCI) | ITU | https://www.itu.int/en/ITU-D/Cybersecurity/pages/global-cybersecurity-index.aspx | country-(edition) | broad global | edition-based | cybersecurity readiness pillars/composite | web publication | readiness is not spending | core readiness proxy |
| Number of disclosed cyber incidents per country (Annex) | World Bank | https://documents.worldbank.org/en/publication/documents-reports/documentdetail/099092324164513733/p1787691fbc9980d19c891b7e706e6f352 | country-year | global sample | 2014-2022 | disclosed incident counts | annex document/table extraction | disclosure-dependent counts | incident exposure proxy |
| CISSM Cyber Events Database | CISSM (University of Maryland) | https://cissm.umd.edu/cyber-events-database | event-level | multi-country | ongoing (source-dependent) | event metadata (target, date, type) | web database/download | reporting and coding heterogeneity | event-to-country-year aggregation |
| EuRepoC Cyber Incidents Database | EuRepoC | https://eurepoc.eu/database/ | incident/event-level | multi-country | ongoing/releases | incident coding fields | web database/release files | evolving schema/coverage | robustness incident source |
| Penn World Table | Groningen Growth and Development Centre | https://www.rug.nl/ggdc/productivity/pwt/ | country-year | broad global | long historical panel | productivity and macro aggregates | web download | version-specific methodology | productivity outcomes/controls |

## References (APA)

Cobos, E. V., & Cakir, S. (2024). *A review of the economic costs of cyber incidents*. World Bank. https://documents1.worldbank.org/curated/en/099092324164536687/pdf/P17876919ffee4079180e81701969ad0a18.pdf

Feenstra, R. C., Inklaar, R., & Timmer, M. P. (2024). *Penn World Table (Version 11)* [Data set]. Groningen Growth and Development Centre, University of Groningen. https://www.rug.nl/ggdc/productivity/pwt/

International Telecommunication Union. (n.d.-a). *Global cybersecurity index*. https://www.itu.int/en/ITU-D/Cybersecurity/pages/global-cybersecurity-index.aspx

International Telecommunication Union. (n.d.-b). *ICT Development Index (IDI)*. https://www.itu.int/en/ITU-D/Statistics/Pages/IDI/default.aspx

International Telecommunication Union. (n.d.-c). *ITU DataHub*. https://datahub.itu.int/

Kopp, E., Kaffenberger, L., & Wilson, C. (2017). *Cyber risk, market failures, and financial stability* (IMF Working Paper No. 2017/185). International Monetary Fund. https://doi.org/10.5089/9781484313787.001

Organisation for Economic Co-operation and Development. (2024). *New perspectives on measuring cybersecurity* (OECD Digital Economy Papers No. 366). OECD Publishing. https://doi.org/10.1787/b1e31997-en

World Bank. (n.d.-a). *About the Indicators API documentation*. https://datahelpdesk.worldbank.org/knowledgebase/articles/889392-about-the-indicators-api-documentation

World Bank. (n.d.-b). *World Development Indicators*. https://databank.worldbank.org/source/world-development-indicators

World Bank. (n.d.-c). *Digital Adoption Index*. https://www.worldbank.org/en/publication/wdr2016/Digital-Adoption-Index

World Bank. (n.d.-d). *GovTech Maturity Index (GTMI)*. https://www.worldbank.org/en/programs/govtech/gtmi

World Bank. (n.d.-e). *GovTech dataset*. https://datacatalog.worldbank.org/search/dataset/0037889/govtech-dataset

World Bank. (2024). *A review of the economic costs of cyber incidents: Annex - Number of disclosed cyber incidents per country 2014-2022*. https://documents.worldbank.org/en/publication/documents-reports/documentdetail/099092324164513733/p1787691fbc9980d19c891b7e706e6f352

Centre for International and Security Studies at Maryland. (n.d.). *Cyber events database*. https://cissm.umd.edu/cyber-events-database

EuRepoC. (n.d.). *Cyber incidents database*. https://eurepoc.eu/database/
