# Phase 4 and Future Workflows

Phase 3 (GCI scale sensitivity, heterogeneity documentation, code hardening) is now complete. The pilot has delivered a reproducible MVP with dual-pathway readiness sensitivity analysis and documented income-group heterogeneity. The following Phase 4 extensions are recommended.

## Phase 4a: Temporal dynamics and distributed lags

**Objective**: Test whether incident exposure or readiness changes predict future macro outcomes over multi-year horizons.

**Method**: Extend FE estimation sequence to include lagged specifications $k=1,2,3$ as outlined in the empirical strategy. Fit:
$$y_{it} = \beta_1 C_{i,t-1} + \beta_2 C_{i,t-2} + \beta_3 C_{i,t-3} + \gamma'X_{i,t-1} + \alpha_i + \lambda_t + \varepsilon_{it}$$

- Cluster standard errors by country; test joint significance of lags.
- Report lag-aggregated and cumulative impulse responses.
- Compare cumulative effects across income groups.

**Deliverables**: 
- Distributed-lag coefficient tables (incidents, GCI level, GCI normalized)
- Dynamic impulse-response figures with 95% confidence bands
- Lag-aggregated policy-relevant summary (e.g., "readiness effect peaks at year 2")

**Rationale**: The current pilot estimates $k=1$ only. Distributed lags test whether effects operate over longer horizons and help distinguish between immediate shocks and structural adaptation costs.

---

## Phase 4b: Sectoral and outcome heterogeneity

**Objective**: Test whether cyber-macro associations differ by economic sector or outcome type.

**Method**:
- Extract sector-specific outcomes from WDI if available (e.g., ICT/telecom services, manufacturing output, financial sector indicators).
- Fit heterogeneous specifications by outcome domain:
  - Real GDP growth
  - Investment share
  - Labor force participation / employment
  - Productivity (output per worker)
  - Trade intensity
- Document which outcome pairs are most sensitive to cyber or readiness variation.
- Visualize outcome-level heterogeneity heatmaps.

**Deliverables**: 
- Sectoral outcome comparison tables (incidents + GCI level + GCI normalized by outcome type)
- Heatmaps showing coefficient magnitude and significance by outcome/regressor pair
- Policy brief highlight: "Cyber incidents most strongly associated with changes in IT/telecom sector output" (example)

**Rationale**: Cyber threats may have asymmetric impacts by sector. Finance and ICT sectors may be more sensitive to incident exposure than agriculture or construction. This extension tests scope and generalizability.

---

## Phase 4c: Machine learning and feature importance

**Objective**: Use non-parametric methods to assess relative importance of cyber vs. other macro drivers and detect non-linear effects.

**Method**:
- Fit random forest or gradient boosting (e.g., xgboost, LightGBM) on the same panel dataset.
- Features: lagged incidents, lagged GCI (level + normalized), lagged macro controls (inflation, trade, population, digital adoption).
- Targets: same macro outcomes as baseline FE (GDP growth, investment, productivity, etc.).
- Extract feature importance scores (e.g., SHAP values, mean decrease in impurity, permutation importance).
- Compare feature rankings across outcome types and income-group subsamples.
- Identify interaction effects and threshold behaviors via partial-dependence plots.

**Deliverables**: 
- Feature importance bar charts (cyber regressors ranked vs. macro controls)
- SHAP dependence plots showing non-linear relationships
- Interaction heatmaps (e.g., incident sensitivity conditional on readiness level)
- Comparative discussion: "ML feature importance and FE coefficients show consistent ranking; both methods flag incidents as top 3 driver"

**Rationale**: Parametric FE models assume linear effects and common slopes. ML methods detect non-linearities, interaction effects, and can highlight which countries/years drive coefficient estimates. This strengthens confidence in findings and identifies candidate heterogeneity.

---

## Phase 4d: Event study and incident-level analysis

**Objective**: Trace out the dynamic macro effects of discrete cyber events (e.g., major ransomware campaigns, supply-chain incidents).

**Method**:
- Aggregate incident-level data by country, quarter, and incident category if available (ransomware, data theft, infrastructure, etc.).
- Construct event window indicators (e.g., $\text{event}_{it} = 1$ if country-quarter experiences ≥N incidents, else 0).
- Fit dynamic treatment specification with leads/lags:
  $$y_{it} = \sum_{k=-4}^{4} \gamma_k \cdot \text{event}_{i,t+k} + X'_{it} \lambda + \alpha_i + \tau_t + \varepsilon_{it}$$
- Estimate average treatment effect on treated (ATT) with 95% confidence bands.
- Stratify by incident type, country group, and outcome type.

**Deliverables**: 
- Event-study coefficient plots with confidence bands (showing lead/lag structure)
- ATT summary table with heterogeneity by incident type
- Discussion of timing and policy implications (e.g., "effects persist 2+ quarters post-event")

**Rationale**: Aggregate annual models may obscure intra-year shocks. Event studies allow precise timing and causal attribution through diff-in-diff intuition. High temporal resolution improves policy relevance.

---

## Phase 4e: Publication and stakeholder communication

**Objective**: Prepare pilot findings for external peer review and policy engagement.

**Actions**:

1. **Policy brief** (~4–6 pages)
   - Headline findings: magnitude, direction, heterogeneity by income group
   - Policy implications: readiness investment ROI, incident prevention priority, sectoral focus areas
   - Limitations and caveats (measurement, causality, sample)
   - Audience: policymakers, development practitioners

2. **Academic paper** (~30–40 pages, target journals: macro, development, cyber-security economics)
   - Motivation and literature review
   - Data and empirical strategy (detailed)
   - Results: baseline, robustness, heterogeneity, extensions
   - Discussion of identification and policy implications
   - Appendix: additional results, sensitivity analysis, replication code

3. **Repository archival**
   - Add persistent DOI via Zenodo, OSF, or institutional repository
   - Document reproducibility path: `renv::restore()`, one-command run instructions, CI/CD setup
   - Create reproducibility checklist (data access, code versions, runtime)
   - Tag final release version in GitHub

4. **CI/CD and long-term maintenance**
   - Set up GitHub Actions for automated data refresh (e.g., WDI, ITU API) quarterly
   - Automated test suite for schema validation and pipeline robustness
   - Scheduled report rendering and output archival
   - Communication plan for data updates or methodological changes

5. **Preprint and early feedback**
   - Consider arXiv (econ) or SSRN (policy) preprint to signal work and gather feedback before peer review
   - Set up OSF project for version control and preregistration (optional)

**Deliverables**: 
- Policy brief PDF
- Academic manuscript (tex/Rmd + compiled PDF)
- DOI-linked repository archive
- Reproducibility checklist and CI/CD workflow
- Preprint on arXiv/SSRN (optional)

**Rationale**: Publication amplifies impact and external validation. Open data + code + preprint establish credibility and long-term accessibility for future researchers and policymakers.

---

## Implementation priorities and sequencing

### High priority (align with research framework and source spine, deliver actionable policy signals)

1. **Phase 4e (Publication and stakeholder communication)** — highest impact for credibility and reach; enables simultaneous peer/policy feedback
2. **Phase 4a (Temporal dynamics)** — completes the empirical strategy outlined in deep-research-report.md Section 3; tests persistence of effects
3. **Phase 4b (Outcome heterogeneity)** — tests generalizability and policy relevance across macro domains

### Medium priority (novel but higher implementation risk and interpretation complexity)

4. **Phase 4c (Machine learning)** — addresses feature importance but requires careful validation against parametric results to avoid false discoveries
5. **Phase 4d (Event study)** — more granular incident-level analysis but depends on data availability (country-quarter disaggregation, incident categorization) and methodological choices (event threshold, window length)

---

## Resource estimates and recommended team composition

### Phase 4a (Distributed lags): 2–3 weeks
- 1–2 FTE: extended R/04 specs, new tables/figures, report section
- Outputs: 5–10 new model specifications, 3–4 figures

### Phase 4b (Sectoral heterogeneity): 3–4 weeks
- 1–2 FTE: WDI outcome extraction, model re-fitting by sector, visualization
- Risk: WDI sector coverage may be limited; fallback to regional heterogeneity
- Outputs: outcome × regressor comparison tables, heatmaps, policy brief section

### Phase 4c (Machine learning): 4–6 weeks
- 1–2 FTE: ML model fitting, feature extraction, validation against FE results, writeup
- Risk: hyperparameter tuning, overfitting, interpretation transparency
- Outputs: feature importance plots, SHAP analysis, robustness discussion

### Phase 4d (Event study): 4–6 weeks
- 1–2 FTE: incident-level data prep, event window construction, dynamic model fitting, visualization
- Risk: event categorization, frequency choice, multiple comparisons
- Outputs: event-study figures, ATT table, heterogeneity by incident type

### Phase 4e (Publication): 6–10 weeks
- 1–2 FTE: writing (policy brief, academic paper), external communication, archival setup, CI/CD
- 0.5 FTE: peer/stakeholder feedback loop and revision cycles
- Outputs: 2 manuscripts, DOI archive, reproducibility checklist, GitHub Actions workflows

---

## Success criteria

Each phase is considered complete when:

- **Phase 4a**: Distributed-lag models estimated and reported; cumulative effect interpretation provided; no new data quality issues introduced
- **Phase 4b**: All outcome types fitted; heterogeneity table generated; at least 3 sector-specific policy findings documented
- **Phase 4c**: ML models trained and validated; feature importance concordance with FE results >70%; interpretation briefing completed
- **Phase 4d**: Event-study figures and ATT tables generated; lead/lag structure and timing interpretable; incident categorization transparent
- **Phase 4e**: Policy brief and academic manuscript drafted and reviewed; persistent DOI assigned; CI/CD workflows operational

---

## Next meeting agenda (proposed)

1. **Prioritization**: Which Phase 4 extensions are most aligned with stakeholder interest and available resources?
2. **Sequencing**: Should publication (Phase 4e) begin immediately in parallel with technical extensions, or after?
3. **Scope adjustments**: Any changes to outcome types, sector focus, or methodological choices?
4. **Resource commitment**: Timeline and team composition for chosen phases?
