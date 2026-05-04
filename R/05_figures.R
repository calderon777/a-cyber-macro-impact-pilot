suppressPackageStartupMessages({
	library(dplyr)
	library(ggplot2)
	library(arrow)
	library(fixest)
})

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

panel_path <- "data_processed/panel_country_year.parquet"
fig_structural <- "output/figures/partial_correlation_scatter.png"
fig_dynamic <- "output/figures/dynamic_fallback_trend.png"
data_structural <- "output/figures/partial_correlation_data.csv"
data_dynamic <- "output/figures/dynamic_fallback_data.csv"

if (!file.exists(panel_path)) {
	stop("Missing panel file: ", panel_path, ". Run R/03_build_panel.R first.")
}

panel <- arrow::read_parquet(panel_path) %>%
	mutate(
		iso3c = as.character(iso3c),
		year = as.integer(year)
	) %>%
	arrange(iso3c, year)

create_lag <- function(df, var_name, k = 1L) {
	if (!var_name %in% names(df)) {
		return(df)
	}
	lag_name <- paste0("l", k, "_", var_name)
	df %>%
		group_by(iso3c) %>%
		arrange(year, .by_group = TRUE) %>%
		mutate(!!lag_name := dplyr::lag(.data[[var_name]], n = k)) %>%
		ungroup()
}

candidate_regressors <- c(
	"cyber_incidents_log",
	"gci_overall",
	"gtmi_overall",
	"cyber_spend_gdp_optional",
	"internet_users_pct"
)

y_var <- if ("gdp_per_person_employed" %in% names(panel)) {
	"gdp_per_person_employed"
} else if ("gdp_growth" %in% names(panel)) {
	"gdp_growth"
} else {
	stop("No supported outcome available for structural chart.")
}

available_regressors <- candidate_regressors[candidate_regressors %in% names(panel)]
if (length(available_regressors) == 0) {
	stop("No supported regressor available for figure generation.")
}

main_regressor <- NA_character_
for (candidate in available_regressors) {
	p <- create_lag(panel, candidate, 1L)
	x_name <- paste0("l1_", candidate)
	n_obs <- p %>%
		filter(!is.na(.data[[x_name]]), !is.na(.data[[y_var]])) %>%
		nrow()

	if (n_obs >= 100) {
		main_regressor <- candidate
		panel <- p
		break
	}
}

if (is.na(main_regressor)) {
	stop("No supported regressor has enough lagged observations for figure generation.")
}

x_var <- paste0("l1_", main_regressor)

structural_df <- panel %>%
	filter(!is.na(.data[[x_var]]), !is.na(.data[[y_var]]))

if (nrow(structural_df) < 100) {
	stop("Too few observations for structural scatter after lag/filter operations.")
}

# Use lm with fixed-effect dummies to keep residual vectors aligned to original rows.
y_resid_fit <- stats::lm(
	as.formula(paste0(y_var, " ~ factor(iso3c) + factor(year)")),
	data = structural_df
)

x_resid_fit <- stats::lm(
	as.formula(paste0(x_var, " ~ factor(iso3c) + factor(year)")),
	data = structural_df
)

plot_df <- structural_df %>%
	transmute(
		iso3c,
		year,
		x_resid = as.numeric(resid(x_resid_fit)),
		y_resid = as.numeric(resid(y_resid_fit))
	)

write.csv(plot_df, data_structural, row.names = FALSE)

p_structural <- ggplot(plot_df, aes(x = x_resid, y = y_resid)) +
	geom_point(alpha = 0.20, size = 1.0, color = "#1f4e79") +
	geom_smooth(method = "lm", se = FALSE, linewidth = 0.9, color = "#c24e00") +
	labs(
		title = "Partial Correlation: Cyber Proxy and Productivity Outcome",
		x = paste0("Residualized lagged ", main_regressor, " (country and year FE removed)"),
		y = paste0("Residualized ", y_var, " (country and year FE removed)")
	) +
	theme_minimal(base_size = 11)

ggsave(fig_structural, p_structural, width = 10, height = 6, dpi = 300)

trend_df <- panel %>%
	group_by(year) %>%
	summarise(
		gdp_growth_mean = if ("gdp_growth" %in% names(panel)) mean(gdp_growth, na.rm = TRUE) else NA_real_,
		proxy_mean = mean(.data[[main_regressor]], na.rm = TRUE),
		countries = dplyr::n_distinct(iso3c),
		.groups = "drop"
	)

trend_df <- trend_df %>%
	mutate(
		gdp_growth_idx = as.numeric(scale(gdp_growth_mean)),
		proxy_idx = as.numeric(scale(proxy_mean))
	)

write.csv(trend_df, data_dynamic, row.names = FALSE)

trend_long <- trend_df %>%
	select(year, gdp_growth_idx, proxy_idx) %>%
	tidyr::pivot_longer(
		cols = c(gdp_growth_idx, proxy_idx),
		names_to = "series",
		values_to = "value"
	) %>%
	filter(!is.na(value))

dropped_trend_rows <- nrow(trend_df) * 2L - nrow(trend_long)

p_dynamic <- ggplot(trend_long, aes(x = year, y = value, color = series)) +
	geom_line(linewidth = 1.0) +
	geom_point(size = 1.2) +
	scale_color_manual(
		values = c(gdp_growth_idx = "#1f4e79", proxy_idx = "#c24e00"),
		labels = c(
			gdp_growth_idx = "GDP growth (z-score)",
			proxy_idx = paste0(main_regressor, " (z-score)")
		)
	) +
	labs(
		title = "Cyber Proxy and GDP Growth Trend",
		x = "Year",
		y = "Standardized annual mean",
		color = NULL
	) +
	theme_minimal(base_size = 11)

ggsave(fig_dynamic, p_dynamic, width = 10, height = 6, dpi = 300)

message("Figure generation complete.")
message("Main regressor used: ", main_regressor)
if (dropped_trend_rows > 0) {
	message("Trend plot omitted missing series-year points: ", dropped_trend_rows)
}
message("Wrote: ", fig_structural)
message("Wrote: ", fig_dynamic)
