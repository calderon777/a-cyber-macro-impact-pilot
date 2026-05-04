suppressPackageStartupMessages({
	library(dplyr)
	library(tidyr)
	library(arrow)
})

# Helper: linear interpolation between anchor years + bounded carry-forward/backward
gci_interpolate <- function(yr, val) {
	obs <- which(!is.na(val))
	if (length(obs) == 0) return(val)
	out <- val
	if (length(obs) >= 2) {
		out <- stats::approx(yr[obs], val[obs], xout = yr, rule = 1)$y
	}
	# carry backward from first anchor
	out[yr < yr[obs[1]]]           <- val[obs[1]]
	# carry forward from last anchor
	out[yr > yr[obs[length(obs)]]] <- val[obs[length(obs)]]
	out
}

dir.create("data_processed", showWarnings = FALSE)

harmonised_path <- "data_processed/wdi_core_harmonised_long.csv"
indicator_map_path <- "data_raw/wdi/wdi_indicator_map.csv"
panel_path <- "data_processed/panel_country_year.parquet"
dictionary_path <- "data_processed/data_dictionary.csv"

if (!file.exists(harmonised_path)) {
	stop("Missing harmonised input: ", harmonised_path, ". Run R/02_clean_harmonise.R first.")
}

long_df <- read.csv(harmonised_path, stringsAsFactors = FALSE)

panel <- long_df %>%
	select(iso3c, country, year, variable, value) %>%
	mutate(year = as.integer(year)) %>%
	group_by(iso3c, country, year, variable) %>%
	summarise(value = dplyr::first(value), .groups = "drop") %>%
	tidyr::pivot_wider(
		names_from = variable,
		values_from = value
	) %>%
	arrange(iso3c, year)

# ── GCI interpolation / carry-forward ────────────────────────────────────────
# GCI anchor years are 2020 (scores 0-100) and 2024 (tier midpoints).
# Linearly interpolate gci_overall for 2021-2023; carry backward from 2020
# and forward from 2024 for years outside the anchor range.
# gci_overall_imputed = TRUE flags rows whose value was derived, not observed.
if ("gci_overall" %in% names(panel)) {
	panel <- panel %>%
		group_by(iso3c) %>%
		arrange(year) %>%
		mutate(
			.gci_anchor       = !is.na(gci_overall),
			gci_overall       = gci_interpolate(year, gci_overall),
			gci_overall_imputed = !.gci_anchor & !is.na(gci_overall)
		) %>%
		select(-.gci_anchor) %>%
		ungroup() %>%
		arrange(iso3c, year)

	n_imputed <- sum(panel$gci_overall_imputed, na.rm = TRUE)
	message("GCI interpolation: ", n_imputed, " country-year values imputed (non-anchor).")
}

arrow::write_parquet(panel, panel_path)

if (file.exists(indicator_map_path)) {
	indicator_map <- read.csv(indicator_map_path, stringsAsFactors = FALSE)
	data_dictionary <- long_df %>%
		distinct(variable, indicator) %>%
		left_join(indicator_map, by = c("indicator", "variable")) %>%
		transmute(
			variable,
			indicator,
			source = dplyr::case_when(
				indicator == "GCI_OPEN" ~ "ITU GCI tier extraction",
				indicator == "INCIDENTS_OPEN" ~ "Open incidents source",
				TRUE ~ "World Development Indicators"
			),
			frequency = "annual",
			transform = "none"
		) %>%
		arrange(variable)
} else {
	data_dictionary <- long_df %>%
		distinct(variable, indicator) %>%
		transmute(
			variable,
			indicator,
			source = dplyr::case_when(
				indicator == "GCI_OPEN" ~ "ITU GCI tier extraction",
				indicator == "INCIDENTS_OPEN" ~ "Open incidents source",
				TRUE ~ "World Development Indicators"
			),
			frequency = "annual",
			transform = "none"
		) %>%
		arrange(variable)
}

# Append derived GCI flag if it was created
if ("gci_overall_imputed" %in% names(panel)) {
	gci_flag_row <- data.frame(
		variable  = "gci_overall_imputed",
		indicator = "GCI_OPEN",
		source    = "Derived: linear interpolation between GCI 2020 and 2024 anchor years",
		frequency = "annual",
		transform = "flag"
	)
	data_dictionary <- dplyr::bind_rows(data_dictionary, gci_flag_row) %>%
		arrange(variable)
}

write.csv(data_dictionary, dictionary_path, row.names = FALSE)

message("Panel build complete.")
message("Rows in panel: ", nrow(panel))
message("Wrote: ", panel_path)
message("Wrote: ", dictionary_path)

# Expected outputs
# data_processed/panel_country_year.parquet
# data_processed/data_dictionary.csv
