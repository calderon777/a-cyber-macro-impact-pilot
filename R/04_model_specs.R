suppressPackageStartupMessages({
	library(dplyr)
	library(fixest)
	library(modelsummary)
	library(arrow)
})

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)

panel_path <- "data_processed/panel_country_year.parquet"
headline_html <- "output/tables/headline_regressions.html"
robust_html <- "output/tables/robustness_regressions.html"
headline_csv <- "output/tables/headline_regressions.csv"
robust_csv <- "output/tables/robustness_regressions.csv"

if (!file.exists(panel_path)) {
	stop("Missing panel file: ", panel_path, ". Run R/03_build_panel.R first.")
}

panel <- arrow::read_parquet(panel_path) %>%
	mutate(
		iso3c = as.character(iso3c),
		year = as.integer(year)
	) %>%
	arrange(iso3c, year)

if (!all(c("iso3c", "year") %in% names(panel))) {
	stop("Panel must include iso3c and year columns.")
}

create_lags <- function(df, vars, lags = 1:3, group_col = "iso3c") {
	for (v in vars) {
		if (!v %in% names(df)) {
			next
		}
		for (k in lags) {
			lag_name <- paste0("l", k, "_", v)
			df <- df %>%
				group_by(.data[[group_col]]) %>%
				arrange(year, .by_group = TRUE) %>%
				mutate(!!lag_name := dplyr::lag(.data[[v]], n = k)) %>%
				ungroup()
		}
	}
	df
}

candidate_regressors <- c(
	"gci_overall",
	"cyber_incidents_log",
	"gtmi_overall",
	"cyber_spend_gdp_optional",
	"internet_users_pct"
)

main_regressor <- dplyr::first(candidate_regressors[candidate_regressors %in% names(panel)])
if (is.na(main_regressor) || length(main_regressor) == 0) {
	stop("No supported main regressor found in panel.")
}

outcomes <- c(
	"gdp_growth",
	"gdp_per_person_employed",
	"gcf_gdp",
	"employment_ratio"
)
outcomes <- outcomes[outcomes %in% names(panel)]

if (length(outcomes) == 0) {
	stop("No supported outcome variables found in panel.")
}

controls <- c("inflation_cpi", "trade_gdp", "population_total")
controls <- controls[controls %in% names(panel)]

lag_vars <- unique(c(main_regressor, controls))
panel <- create_lags(panel, vars = lag_vars, lags = 1:3)

baseline_models <- list()
robust_models <- list()

for (y in outcomes) {
	baseline_terms <- c(paste0("l1_", main_regressor), paste0("l1_", controls))
	baseline_terms <- baseline_terms[baseline_terms %in% names(panel)]

	if (length(baseline_terms) == 0) {
		next
	}

	baseline_formula <- as.formula(
		paste0(y, " ~ ", paste(baseline_terms, collapse = " + "), " | iso3c + year")
	)

	robust_terms <- c(
		paste0("l2_", main_regressor),
		paste0("l3_", main_regressor),
		paste0("l1_", controls)
	)
	robust_terms <- robust_terms[robust_terms %in% names(panel)]

	robust_formula <- as.formula(
		paste0(y, " ~ ", paste(robust_terms, collapse = " + "), " | iso3c + year")
	)

	baseline_models[[y]] <- fixest::feols(
		baseline_formula,
		data = panel,
		cluster = ~iso3c
	)

	robust_models[[y]] <- fixest::feols(
		robust_formula,
		data = panel,
		cluster = ~iso3c
	)
}

if (length(baseline_models) == 0) {
	stop("No estimable baseline models were produced.")
}

modelsummary::modelsummary(
	baseline_models,
	output = headline_html,
	stars = TRUE,
	goftable = "nobs"
)

modelsummary::modelsummary(
	robust_models,
	output = robust_html,
	stars = TRUE,
	goftable = "nobs"
)

headline_df <- modelsummary::modelsummary(
	baseline_models,
	output = "data.frame",
	stars = TRUE,
	goftable = "nobs"
)

robust_df <- modelsummary::modelsummary(
	robust_models,
	output = "data.frame",
	stars = TRUE,
	goftable = "nobs"
)

write.csv(headline_df, headline_csv, row.names = FALSE)
write.csv(robust_df, robust_csv, row.names = FALSE)

message("Model specification step complete.")
message("Main regressor used: ", main_regressor)
message("Outcomes modeled: ", paste(outcomes, collapse = ", "))
message("Wrote: ", headline_html)
message("Wrote: ", robust_html)
