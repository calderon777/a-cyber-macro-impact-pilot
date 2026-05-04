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
comparison_html <- "output/tables/incidents_vs_readiness_regressions.html"
comparison_csv <- "output/tables/incidents_vs_readiness_regressions.csv"

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

cyber_priority_regressors <- c(
	"cyber_incidents_log",
	"gci_overall",
	"gtmi_overall",
	"cyber_spend_gdp_optional"
)
context_fallback_regressor <- "internet_users_pct"
allow_context_fallback <- tolower(Sys.getenv("ALLOW_CONTEXT_FALLBACK", unset = "false")) %in% c("1", "true", "yes")

available_cyber <- cyber_priority_regressors[cyber_priority_regressors %in% names(panel)]

if (length(available_cyber) > 0) {
	main_regressor <- dplyr::first(available_cyber)
	regressor_mode <- "cyber-primary"
} else if (context_fallback_regressor %in% names(panel)) {
	if (!allow_context_fallback) {
		stop(
			"No cyber regressor found in panel. Set ALLOW_CONTEXT_FALLBACK=true to run with internet_users_pct fallback."
		)
	}
	main_regressor <- context_fallback_regressor
	regressor_mode <- "context-fallback"
	warning(
		"Proceeding with context fallback regressor (internet_users_pct). Interpret headline estimates as non-cyber baseline."
	)
} else {
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

available_model_regressors <- unique(c(
	main_regressor,
	cyber_priority_regressors[cyber_priority_regressors %in% names(panel)],
	context_fallback_regressor
))
lag_vars <- unique(c(available_model_regressors, controls))
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

comparison_models <- list()
comparison_regressors <- c("cyber_incidents_log", "gci_overall")
comparison_regressors <- comparison_regressors[comparison_regressors %in% names(panel)]

if (length(comparison_regressors) == 2) {
	for (y in outcomes) {
		for (r in comparison_regressors) {
			terms <- c(paste0("l1_", r), paste0("l1_", controls))
			terms <- terms[terms %in% names(panel)]

			if (length(terms) == 0) {
				next
			}

			needed_cols <- unique(c(y, terms, "iso3c", "year"))
			model_data <- panel %>%
			select(all_of(needed_cols)) %>%
			filter(if_all(all_of(c(y, terms)), ~ !is.na(.x)))

			if (nrow(model_data) < 50) {
				next
			}

			fml <- as.formula(
				paste0(y, " ~ ", paste(terms, collapse = " + "), " | iso3c + year")
			)

			fit <- tryCatch(
				fixest::feols(
					fml,
					data = model_data,
					cluster = ~iso3c
				),
				error = function(e) NULL
			)

			if (!is.null(fit)) {
				comparison_models[[paste0(y, "__", r)]] <- fit
			}
		}
	}
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

if (length(comparison_models) > 0) {
	modelsummary::modelsummary(
		comparison_models,
		output = comparison_html,
		stars = TRUE,
		goftable = "nobs"
	)

	comparison_df <- modelsummary::modelsummary(
		comparison_models,
		output = "data.frame",
		stars = TRUE,
		goftable = "nobs"
	)

	write.csv(comparison_df, comparison_csv, row.names = FALSE)
}

message("Model specification step complete.")
message("Main regressor used: ", main_regressor)
message("Regressor mode: ", regressor_mode)
message("Outcomes modeled: ", paste(outcomes, collapse = ", "))
message("Wrote: ", headline_html)
message("Wrote: ", robust_html)
if (length(comparison_models) > 0) {
	message("Wrote: ", comparison_html)
}
