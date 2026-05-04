suppressPackageStartupMessages({
	library(dplyr)
	library(fixest)
	library(modelsummary)
	library(arrow)
	library(broom)
})

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)

panel_path <- "data_processed/panel_country_year.parquet"
headline_html <- "output/tables/headline_regressions.html"
robust_html <- "output/tables/robustness_regressions.html"
headline_csv <- "output/tables/headline_regressions.csv"
robust_csv <- "output/tables/robustness_regressions.csv"
comparison_html <- "output/tables/incidents_vs_readiness_regressions.html"
comparison_csv <- "output/tables/incidents_vs_readiness_regressions.csv"
headline_compact_csv <- "output/tables/headline_regressions_compact.csv"
robust_compact_csv <- "output/tables/robustness_regressions_compact.csv"
comparison_compact_csv <- "output/tables/incidents_vs_readiness_regressions_compact.csv"
heterogeneity_csv <- "output/tables/heterogeneity_regressions.csv"
gci_qa_csv <- "output/tables/gci_imputation_qa.csv"

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

format_number <- function(x, digits = 3L) {
	ifelse(is.na(x), NA_character_, sprintf(paste0("%.", digits, "f"), x))
}

format_p <- function(p.value) {
	dplyr::case_when(
		is.na(p.value) ~ "",
		p.value < 0.001 ~ "***",
		p.value < 0.01 ~ "**",
		p.value < 0.05 ~ "*",
		p.value < 0.10 ~ "+",
		TRUE ~ ""
	)
}

tidy_model_list <- function(models, spec_label, model_lookup = NULL) {
	if (length(models) == 0) {
		return(data.frame())
	}

	bind_rows(lapply(names(models), function(model_name) {
		fit <- models[[model_name]]
		lookup_row <- if (!is.null(model_lookup)) {
			model_lookup %>% filter(.data$model == model_name) %>% slice(1)
		} else {
			data.frame()
		}

		outcome <- if ("outcome" %in% names(lookup_row) && nrow(lookup_row) > 0) lookup_row$outcome else model_name
		regressor <- if ("regressor" %in% names(lookup_row) && nrow(lookup_row) > 0) lookup_row$regressor else NA_character_
		income_group <- if ("income_group_model" %in% names(lookup_row) && nrow(lookup_row) > 0) lookup_row$income_group_model else NA_character_

		broom::tidy(fit) %>%
			mutate(
				spec = spec_label,
				model = model_name,
				outcome = outcome,
				regressor = regressor,
				income_group_model = income_group,
				estimate_fmt = paste0(format_number(estimate), format_p(p.value)),
				std.error_fmt = paste0("(", format_number(std.error), ")"),
				p.value_fmt = format_number(p.value)
			) %>%
			select(
				spec,
				model,
				outcome,
				income_group_model,
				regressor,
				term,
				estimate,
				std.error,
				p.value,
				estimate_fmt,
				std.error_fmt,
				p.value_fmt
			)
	}))
}

add_nobs <- function(tbl, models) {
	if (nrow(tbl) == 0 || length(models) == 0) {
		return(tbl)
	}

	nobs_tbl <- data.frame(
		model = names(models),
		nobs = as.integer(vapply(models, stats::nobs, FUN.VALUE = numeric(1))),
		stringsAsFactors = FALSE
	)

	left_join(tbl, nobs_tbl, by = "model")
}

fit_fe_model <- function(df, outcome, terms, min_obs = 50L, min_countries = 10L) {
	needed_cols <- unique(c(outcome, terms, "iso3c", "year"))
	model_data <- df %>%
		select(any_of(needed_cols)) %>%
		filter(if_all(all_of(c(outcome, terms)), ~ !is.na(.x)))

	if (
		nrow(model_data) < min_obs ||
		dplyr::n_distinct(model_data$iso3c) < min_countries ||
		dplyr::n_distinct(model_data$year) < 2
	) {
		return(NULL)
	}

	fml <- as.formula(
		paste0(outcome, " ~ ", paste(terms, collapse = " + "), " | iso3c + year")
	)

	tryCatch(
		fixest::feols(fml, data = model_data, cluster = ~iso3c),
		error = function(e) NULL
	)
}

cyber_priority_regressors <- c(
	"cyber_incidents_log",
	"gci_overall",
	"gci_overall_norm",
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
gof_map_nobs <- data.frame(
	raw = "nobs",
	clean = "Num.Obs.",
	fmt = 0,
	stringsAsFactors = FALSE
)

for (y in outcomes) {
	baseline_terms <- c(paste0("l1_", main_regressor), paste0("l1_", controls))
	baseline_terms <- baseline_terms[baseline_terms %in% names(panel)]

	if (length(baseline_terms) == 0) {
		next
	}

	robust_terms <- c(
		paste0("l2_", main_regressor),
		paste0("l3_", main_regressor),
		paste0("l1_", controls)
	)
	robust_terms <- robust_terms[robust_terms %in% names(panel)]

	baseline_fit <- fit_fe_model(panel, y, baseline_terms)
	if (!is.null(baseline_fit)) {
		baseline_models[[y]] <- baseline_fit
	}

	robust_fit <- fit_fe_model(panel, y, robust_terms)
	if (!is.null(robust_fit)) {
		robust_models[[y]] <- robust_fit
	}
}

if (length(baseline_models) == 0) {
	stop("No estimable baseline models were produced.")
}

comparison_models <- list()
comparison_lookup <- data.frame()
comparison_regressors <- c("cyber_incidents_log", "gci_overall", "gci_overall_norm")
comparison_regressors <- comparison_regressors[comparison_regressors %in% names(panel)]
has_incidents <- "cyber_incidents_log" %in% comparison_regressors
has_readiness <- any(c("gci_overall", "gci_overall_norm") %in% comparison_regressors)

if (has_incidents && has_readiness) {
	for (y in outcomes) {
		for (r in comparison_regressors) {
			# Incidents and readiness regressors share the same lagged FE spec.
			# Readiness can include level GCI (gci_overall) and normalized
			# percentile sensitivity (gci_overall_norm).
			terms <- c(paste0("l1_", r), paste0("l1_", controls))
			terms <- terms[terms %in% names(panel)]

			if (length(terms) == 0) {
				next
			}

			needed_cols <- unique(c(y, terms, "iso3c", "year"))
			model_data <- panel %>%
			select(any_of(needed_cols)) %>%
			filter(if_all(all_of(c(y, terms)), ~ !is.na(.x)))

			if (nrow(model_data) < 50) {
				next
			}

			has_multi_year <- dplyr::n_distinct(model_data$year) > 1
			has_panel_depth <- dplyr::n_distinct(model_data$iso3c) < nrow(model_data)

			if (has_panel_depth && has_multi_year) {
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
			} else if (has_multi_year) {
				# Keep time controls in repeated cross-section settings.
				fml <- as.formula(
					paste0(y, " ~ ", paste(terms, collapse = " + "), " | year")
				)
				fit <- tryCatch(
					fixest::feols(
						fml,
						data = model_data,
						vcov = "hetero"
					),
					error = function(e) NULL
				)
			} else {
				# Pure cross-section: no fixed effects, heteroskedasticity-robust SE.
				fml <- as.formula(
					paste0(y, " ~ ", paste(terms, collapse = " + "))
				)
				fit <- tryCatch(
					fixest::feols(
						fml,
						data = model_data,
						vcov = "hetero"
					),
					error = function(e) NULL
				)
			}

			if (!is.null(fit)) {
				model_name <- paste0(y, "__", r)
				comparison_models[[model_name]] <- fit
				comparison_lookup <- bind_rows(
					comparison_lookup,
					data.frame(
						model = model_name,
						outcome = y,
						regressor = r,
						outcome_sd = stats::sd(model_data[[y]], na.rm = TRUE),
						regressor_sd = stats::sd(model_data[[paste0("l1_", r)]], na.rm = TRUE),
						stringsAsFactors = FALSE
					)
				)
			}
		}
	}
}

heterogeneity_models <- list()
heterogeneity_lookup <- data.frame()

if ("income_group_model" %in% names(panel) && has_incidents && has_readiness) {
	income_groups <- c("High income", "Upper middle income", "Lower income")

	for (g in income_groups) {
		group_panel <- panel %>%
			filter(income_group_model == g)

		for (y in outcomes) {
			for (r in comparison_regressors) {
				terms <- c(paste0("l1_", r), paste0("l1_", controls))
				terms <- terms[terms %in% names(panel)]

				if (length(terms) == 0) {
					next
				}

				fit <- fit_fe_model(group_panel, y, terms)

				if (!is.null(fit)) {
					model_name <- paste0(g, "__", y, "__", r)
					heterogeneity_models[[model_name]] <- fit
					heterogeneity_lookup <- bind_rows(
						heterogeneity_lookup,
						data.frame(
							model = model_name,
							income_group_model = g,
							outcome = y,
							regressor = r,
							stringsAsFactors = FALSE
						)
					)
				}
			}
		}
	}
}

modelsummary::modelsummary(
	baseline_models,
	output = headline_html,
	stars = TRUE,
	gof_map = gof_map_nobs
)

modelsummary::modelsummary(
	robust_models,
	output = robust_html,
	stars = TRUE,
	gof_map = gof_map_nobs
)

headline_df <- modelsummary::modelsummary(
	baseline_models,
	output = "data.frame",
	stars = TRUE,
	gof_map = gof_map_nobs
)

robust_df <- modelsummary::modelsummary(
	robust_models,
	output = "data.frame",
	stars = TRUE,
	gof_map = gof_map_nobs
)

write.csv(headline_df, headline_csv, row.names = FALSE)
write.csv(robust_df, robust_csv, row.names = FALSE)

headline_compact <- tidy_model_list(baseline_models, "Headline incident FE") %>%
	add_nobs(baseline_models)
robust_compact <- tidy_model_list(robust_models, "Distributed-lag incident FE") %>%
	add_nobs(robust_models)

write.csv(headline_compact, headline_compact_csv, row.names = FALSE)
write.csv(robust_compact, robust_compact_csv, row.names = FALSE)

if (length(comparison_models) > 0) {
	modelsummary::modelsummary(
		comparison_models,
		output = comparison_html,
		stars = TRUE,
		gof_map = gof_map_nobs
	)

	comparison_df <- modelsummary::modelsummary(
		comparison_models,
		output = "data.frame",
		stars = TRUE,
		gof_map = gof_map_nobs
	)

	write.csv(comparison_df, comparison_csv, row.names = FALSE)

	comparison_compact <- tidy_model_list(
		comparison_models,
		"Incidents vs readiness FE",
		comparison_lookup
	) %>%
		left_join(
			comparison_lookup %>%
				select(model, outcome_sd, regressor_sd),
			by = "model"
		) %>%
		mutate(
			std_beta_scale = dplyr::if_else(
				is.na(outcome_sd) | is.na(regressor_sd) | outcome_sd == 0,
				NA_real_,
				regressor_sd / outcome_sd
			),
			std_estimate = estimate * std_beta_scale,
			std_error = std.error * std_beta_scale,
			std_conf.low = std_estimate - 1.96 * std_error,
			std_conf.high = std_estimate + 1.96 * std_error
		) %>%
		add_nobs(comparison_models)

	write.csv(comparison_compact, comparison_compact_csv, row.names = FALSE)
}

if (length(heterogeneity_models) > 0) {
	heterogeneity_df <- tidy_model_list(
		heterogeneity_models,
		"Income-group heterogeneity FE",
		heterogeneity_lookup
	) %>%
		add_nobs(heterogeneity_models)

	write.csv(heterogeneity_df, heterogeneity_csv, row.names = FALSE)
}

if ("gci_overall" %in% names(panel)) {
	gci_qa <- panel %>%
		mutate(
			year_band = dplyr::case_when(
				year < 2020 ~ "2014-2019 carry-backward",
				year == 2020 ~ "2020 observed anchor",
				year %in% 2021:2023 ~ "2021-2023 interpolated",
				year == 2024 ~ "2024 observed anchor",
				year > 2024 ~ "2025 carry-forward",
				TRUE ~ "Other"
			),
			gci_status = dplyr::case_when(
				is.na(gci_overall) ~ "missing",
				!is.na(gci_overall_imputed) & gci_overall_imputed ~ "derived",
				TRUE ~ "observed_anchor"
			)
		) %>%
		count(year_band, gci_status, name = "country_years") %>%
		group_by(year_band) %>%
		mutate(total_country_years = sum(country_years)) %>%
		ungroup() %>%
		arrange(year_band, gci_status)

	write.csv(gci_qa, gci_qa_csv, row.names = FALSE)
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
if (length(heterogeneity_models) > 0) {
	message("Wrote: ", heterogeneity_csv)
}
if (file.exists(gci_qa_csv)) {
	message("Wrote: ", gci_qa_csv)
}
