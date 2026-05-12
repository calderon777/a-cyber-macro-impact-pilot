# Cyber Macro Impact Pilot: Source-Reviewed Research Note

**Dr Camilo Calderon**
camilo.calderon@city.ac.uk

## Executive Summary

This note presents a defensible, reproducible macroeconomic pilot study examining the relationship between cyber risk proxies, cyber investment indicators, and macroeconomic outcomes. The source base supports three conclusions.

Cyber incidents impose material economic costs, but aggregate loss estimates vary substantially across methods and reporting channels (Vergara Cobos & Cakir, 2024). Policy institutions identify structural underinvestment drivers including externalities and information asymmetries (Kopp et al., 2017). Public cross-country data can support an open pilot, but most available indicators capture readiness, digital capability, or incident exposure rather than direct cyber spending (OECD, 2024; ITU, n.d.-a; ITU, n.d.-b).

The analysis maintains five analytically distinct constructs:

1. Cyber spending (direct expenditure)
2. Cyber readiness/capability (institutional and policy capacity)
3. Incident exposure (event counts/intensity)
4. Cyber losses (economic damage)
5. Digital adoption/context (broader digitalization controls)

Baseline panel estimates should be interpreted as associational unless stronger identification is established.

## Literature Synthesis

### Supported Findings

1. Economic costs are material, but measurement is fragmented. The World Bank review shows that estimates vary with definitions, reporting channels, and valuation methods (Vergara Cobos & Cakir, 2024).
2. Macro-financial policy relevance is conceptually strong. IMF analysis identifies market failures in cyber risk management consistent with a role for regulation and coordinated public action (Kopp et al., 2017).
3. Measurement strategy must be explicit. OECD guidance on cybersecurity measurement stresses multidimensional indicators and warns against one-dimensional proxying (OECD, 2024).

### Evidence Gaps

1. Clean global causal estimates of country-year cyber spending on GDP are not established in the supplied evidence base.
2. Public, internationally comparable country-year cyber spending series are limited in open form.
3. Incident datasets are often disclosure-dependent; observed incidents should be treated as lower-bound exposure indicators.

### Interpretation Standard

Baseline panel findings should be framed using language such as *associated with*, *consistent with*, and *suggests*. Causal claims should be reserved for designs with explicit, testable identification assumptions.

## Data Inventory

### Variable Taxonomy

1. Cyber spending: direct expenditures on cybersecurity goods/services (preferred but sparse in open data).
2. Cyber readiness: legal, institutional, governance, and capability indicators.
3. Incident exposure: country-year incident counts or rates.
4. Cyber losses: direct and indirect damage estimates (often heterogeneous and non-comparable).
5. Digital adoption/context: internet and digitalization controls used to reduce omitted-variable bias.

### Open Data Architecture

1. Macro outcomes and controls from World Development Indicators (World Bank, n.d.-a; World Bank, n.d.-b).
2. Cyber readiness and ICT context from ITU sources and related international indicators (ITU, n.d.-a; ITU, n.d.-b).
3. Incident exposure from open incident repositories (World Bank Annex, 2014–2022; CISSM; EuRepoC).
4. Productivity complements from Penn World Table (Feenstra et al., 2024).

## Empirical Strategy

The baseline panel specification is:

$$
y_{it} = \beta C_{i,t-k} + \gamma'X_{i,t-k} + \alpha_i + \lambda_t + \varepsilon_{it}
$$

Definitions:

1. $y_{it}$: macro outcomes (e.g., GDP growth, productivity proxy, investment share, employment ratio)
2. $C_{i,t-k}$: one cyber family at a time (readiness, incidents, or optional spending)
3. $X_{i,t-k}$: controls (inflation, trade, population, and digital context)
4. $\alpha_i$: country fixed effects
5. $\lambda_t$: year fixed effects

**Estimation Sequence**

1. Baseline fixed-effects specification with $k=1$ lag (implemented: incident and dual GCI readiness pathways)
2. Distributed-lag fixed-effects specification with $k=1,2,3$ (planned extension)
3. Heterogeneity analysis by income group and region (implemented: High income, Upper middle income, and Lower income strata)
4. Sensitivity analysis with alternate cyber index families and sample restrictions (implemented: dual GCI pathway; GTMI and NCSI evaluated and excluded due to limited historical coverage)

**Interpretation Principles**

1. Treat baseline coefficients as conditional associations.
2. Report directional evidence, not causal effect sizes, unless identification assumptions are explicitly stated and tested.

### Analytical Implementation

The repository implements a dual-pathway readiness sensitivity analysis and documents heterogeneity by income group. Key specifications are as follows.

1. **Incident exposure models** use lagged terms (e.g., `l1_cyber_incidents_log`) in country and year fixed-effects panel regressions across the full panel (2,696 rows, 224 countries, 2014–2025).

2. **GCI readiness models—level scale** use lagged `l1_gci_overall` (0–100 scale). GCI values for 2021–2023 are linearly interpolated between the 2020 edition (direct scores 0–100) and the 2024 edition (tier midpoints). Earlier panel years carry the 2020 value backward; later years carry the 2024 value forward. The `gci_overall_imputed` flag distinguishes observed anchor years from derived values.

3. **GCI readiness models—normalized scale** use lagged `l1_gci_overall_norm` (percentile-scaled 0–1 within edition). The normalized variant applies the same interpolation and carry rules as the level-scale GCI, ensuring comparability of scale-sensitivity bounds. Coefficients on normalized GCI in aggregate models are not individually significant, but heterogeneity checks show consistent directional alignment with level-scale results across income groups.

4. **Heterogeneity stratification** by World Bank income-group classification (High income, Upper middle income, Lower income pooled) reveals that incident and readiness associations are robust across income groups, though heterogeneity sample sizes are smaller. World Bank metadata assignment leaves 11 country/territory codes without income-group classification; this is documented as a caveat in model interpretation.

5. **Fallback specification**: When readiness data do not support two-way fixed effects (e.g., insufficient observations after listwise deletion), the comparison pathway falls back to time-only fixed effects or cross-section specification with heteroskedasticity-robust standard errors, depending on sample structure.

**Additional readiness indices evaluated**: The Global Cybersecurity Maturity Index (GTMI) and National Cyber Security Index (NCSI) were assessed for inclusion. Both offer limited historical coverage (typically post-2020) and do not provide continuous annual series across the full 2014–2025 panel scope. The dual-pathway GCI sensitivity specification (level and normalized) is retained as the primary readiness specification; GTMI and NCSI are noted as potential future extensions if extended historical data become available.

**Practical implications**: With interpolation and carry rules in place, both incident and dual-GCI columns in the comparison table share the same lagged two-way fixed-effects estimand, making coefficient magnitudes more directly comparable. Derived GCI values (2021–2023 interpolation; pre-2020 and post-2024 carry) are a maintained approximation; directional interpretation is appropriate, but causal ranking should remain cautious. The normalized-scale variant provides an explicit check against scale-inconsistency risk across GCI editions.

## Data Pipeline and Reproducibility

The analysis follows a sequential pipeline implemented in R:

1. `R/01_download_open_data.R`: Refresh WDI and optional incidents source.
2. `R/02_clean_harmonise.R`: Normalize country-year keys and schema.
3. `R/03_build_panel.R`: Produce panel dataset and data dictionary.
4. `R/04_model_specs.R`: Estimate fixed-effects and robustness models.
5. `R/05_figures.R`: Generate structural and dynamic charts.
6. `report.qmd`: Render reproducible narrative output.

Pipeline operations follow three principles: new years are appended incrementally where feasible rather than re-downloading full histories; an audit trail is preserved for all refresh and harmonization operations; and model outputs and rendered artifacts are maintained for external review.

## Limitations

1. **Cyber spending**: Direct country-year cyber spending remains sparse in open sources. Readiness indicators and digital adoption indicators serve as structural proxies but are not equivalent to direct spending measures.

2. **Incident counts**: Incident exposure counts reflect both true exposure and reporting/disclosure differences. The World Bank annex covers 2014–2022; subsequent years in the panel carry forward the last observed value. Incident counts should be treated as lower-bound exposure indicators.

3. **GCI measurement scale discontinuity**: Readiness values for 2021–2023 are linearly interpolated between the 2020 edition (direct scores 0–100) and the 2024 edition (tier midpoints: 97.5, 90, 70, 37.5, 10). Earlier panel years (2014–2020) carry the 2020 value backward; later years (2024–2025) carry the 2024 value forward. The two editions use different measurement approaches, so derived values span two distinct scales. Absolute magnitudes of interpolated GCI values should be interpreted with caution; directional comparisons are more robust. The normalized-scale GCI variant (`gci_overall_norm`, percentile-scaled 0–1 within edition) provides a scale-robust sensitivity check.

4. **GCI coverage gaps**: GCI is available as discrete editions (2020, 2024) rather than annual observations. The interpolation is a pragmatic approximation and should not be interpreted as representing annual observations. The `gci_overall_imputed` flag identifies all derived (non-observed) values.

5. **Income group metadata**: World Bank income-group classification covers 213 of 224 panel countries/territories (95.1%). The 11 unmatched codes are excluded from income-group heterogeneity models; results from heterogeneity checks may not generalize to unmatched regions or country types.

6. **Cross-source methodological heterogeneity**: Coverage, definitions, and collection protocols vary across WDI, ITU, World Bank, and incident sources. These differences may reduce comparability of estimates across outcome and regressor families.

7. **Scope of macro outcomes**: The current implementation addresses macro associations at the country-year level. Event-study designs, sectoral analysis, and firm-level extensions are deferred to future work.

## Claims Audit

| Claim | Source | Source Location | Confidence | Disposition |
|---|---|---|---|---|
| Cyber incidents impose real economic costs, but aggregate estimates vary by method. | Vergara Cobos & Cakir (2024), World Bank | Executive summary and findings sections | High | Retain |
| Measurement fragmentation is a core policy problem in cyber economics. | OECD (2024) | OECD Digital Economy Paper No. 366 | High | Retain |
| Cyber risk can be underpriced due to market failures and externalities. | Kopp et al. (2017), IMF WP 17/185 | Conceptual framework sections | High | Retain |
| Public country-year incident data exist for 2014–2022 via World Bank annex. | World Bank Annex (2014–2022) | Annex dataset page | High | Retain |
| ITU provides cross-country cyber/ICT indicators suitable for readiness context. | ITU DataHub; ITU GCI; ITU IDI pages | Official ITU pages | High | Retain |
| Penn World Table can support productivity-side macro outcomes. | Feenstra et al. (2024), PWT 11 | PWT documentation | High | Retain |
| A specific global causal elasticity of cyber spending on GDP is established in this source set. | No direct evidence in supplied spine | N/A | Low | Exclude |
| Any numeric claim not directly retrievable from cited source text/tables. | N/A | N/A | Low | Pending verification |
| Incident counts are equivalent to monetary cyber loss. | Conceptual contradiction across sources | N/A | Low | Exclude |
| Readiness indices can proxy institutional capacity but are not direct spending measures. | OECD (2024); ITU sources; World Bank digital/governance sources | Methodology/discussion sections | High | Retain |

## Appendix: Data Sources

| Dataset | Organisation | URL | Unit of Observation | Country Coverage | Year Coverage | Key Variables | Access | Main Limitation | Role in Pilot |
|---|---|---|---|---|---|---|---|---|---|
| Indicators API Documentation | World Bank | https://datahelpdesk.worldbank.org/knowledgebase/articles/889392-about-the-indicators-api-documentation | API metadata/spec | Global | N/A (documentation) | API endpoints, parameters | Web/API documentation | Not data itself | Implementation guide |
| World Development Indicators | World Bank | https://databank.worldbank.org/source/world-development-indicators | Country-year | Global | Multi-decade, variable-specific | GDP growth, employment/productivity proxies, inflation, trade, population | Web/API | No direct cyber spending variable | Macro outcomes and controls |
| Digital Adoption Index | World Bank | https://www.worldbank.org/en/publication/wdr2016/Digital-Adoption-Index | Country (wave) | Broad global | Limited waves | Digital adoption sub-indices | Web download | Sparse time frequency | Digital context baseline |
| GovTech Maturity Index | World Bank | https://www.worldbank.org/en/programs/govtech/gtmi | Country (wave) | Broad global | Periodic waves | GovTech maturity pillars | Web download | Low-frequency, partly self-reported | Institutional digital readiness proxy |
| GovTech Dataset | World Bank | https://datacatalog.worldbank.org/search/dataset/0037889/govtech-dataset | Country (wave) | Broad global | Periodic waves | Governance/digital public sector indicators | Data catalog download | Sparse panel | Structural controls/proxy |
| ITU DataHub | ITU | https://datahub.itu.int/ | Country-year/series | Broad global | Series-dependent | ICT/cyber-related indicators | Portal/API export | Indicator definitions vary by series | Cyber/ICT context and readiness |
| ICT Development Index (IDI) | ITU | https://www.itu.int/en/ITU-D/Statistics/Pages/IDI/default.aspx | Country (edition) | Broad global | Edition-based | ICT development composite | Web publication | Methodological discontinuities across editions | Digital capability context |
| Global Cybersecurity Index (GCI) | ITU | https://www.itu.int/en/ITU-D/Cybersecurity/pages/global-cybersecurity-index.aspx | Country (edition) | Broad global | Edition-based | Cybersecurity readiness pillars/composite | Web publication | Readiness is not spending | Core readiness proxy |
| Cyber Incidents per Country (Annex) | World Bank | https://documents.worldbank.org/en/publication/documents-reports/documentdetail/099092324164513733/p1787691fbc9980d19c891b7e706e6f352 | Country-year | Global sample | 2014–2022 | Disclosed incident counts | Annex document/table extraction | Disclosure-dependent counts | Incident exposure proxy |
| CISSM Cyber Events Database | CISSM (University of Maryland) | https://cissm.umd.edu/cyber-events-database | Event-level | Multi-country | Ongoing (source-dependent) | Event metadata (target, date, type) | Web database/download | Reporting and coding heterogeneity | Event-to-country-year aggregation |
| EuRepoC Cyber Incidents Database | EuRepoC | https://eurepoc.eu/database/ | Incident/event-level | Multi-country | Ongoing/releases | Incident coding fields | Web database/release files | Evolving schema and coverage | Robustness incident source |
| Penn World Table | Groningen Growth and Development Centre | https://www.rug.nl/ggdc/productivity/pwt/ | Country-year | Broad global | Long historical panel | Productivity and macro aggregates | Web download | Version-specific methodology | Productivity outcomes/controls |

## References

Feenstra, R. C., Inklaar, R., & Timmer, M. P. (2024). *Penn World Table (Version 11)* [Data set]. Groningen Growth and Development Centre, University of Groningen. https://www.rug.nl/ggdc/productivity/pwt/

International Telecommunication Union. (n.d.-a). *Global cybersecurity index*. https://www.itu.int/en/ITU-D/Cybersecurity/pages/global-cybersecurity-index.aspx

International Telecommunication Union. (n.d.-b). *ICT Development Index (IDI)*. https://www.itu.int/en/ITU-D/Statistics/Pages/IDI/default.aspx

International Telecommunication Union. (n.d.-c). *ITU DataHub*. https://datahub.itu.int/

Kopp, E., Kaffenberger, L., & Wilson, C. (2017). *Cyber risk, market failures, and financial stability* (IMF Working Paper No. 2017/185). International Monetary Fund. https://doi.org/10.5089/9781484313787.001

Organisation for Economic Co-operation and Development. (2024). *New perspectives on measuring cybersecurity* (OECD Digital Economy Papers No. 366). OECD Publishing. https://doi.org/10.1787/b1e31997-en

Vergara Cobos, E., & Cakir, S. (2024). *A review of the economic costs of cyber incidents*. World Bank. https://documents1.worldbank.org/curated/en/099092324164536687/pdf/P17876919ffee4079180e81701969ad0a18.pdf

World Bank. (n.d.-a). *About the Indicators API documentation*. https://datahelpdesk.worldbank.org/knowledgebase/articles/889392-about-the-indicators-api-documentation

World Bank. (n.d.-b). *World Development Indicators*. https://databank.worldbank.org/source/world-development-indicators

World Bank. (n.d.-c). *Digital Adoption Index*. https://www.worldbank.org/en/publication/wdr2016/Digital-Adoption-Index

World Bank. (n.d.-d). *GovTech Maturity Index (GTMI)*. https://www.worldbank.org/en/programs/govtech/gtmi

World Bank. (n.d.-e). *GovTech dataset*. https://datacatalog.worldbank.org/search/dataset/0037889/govtech-dataset

World Bank. (2024). *A review of the economic costs of cyber incidents: Annex—Number of disclosed cyber incidents per country 2014–2022*. https://documents.worldbank.org/en/publication/documents-reports/documentdetail/099092324164513733/p1787691fbc9980d19c891b7e706e6f352

Centre for International and Security Studies at Maryland. (n.d.). *Cyber events database*. https://cissm.umd.edu/cyber-events-database

EuRepoC. (n.d.). *Cyber incidents database*. https://eurepoc.eu/database/
