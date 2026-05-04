suppressPackageStartupMessages({
	library(dplyr)
	library(tidyr)
	library(arrow)
})

# Helper: linear interpolation between anchor years plus bounded carry rules.
gci_interpolate <- function(yr, val) {
	obs <- which(!is.na(val))
	if (length(obs) == 0) return(val)
	out <- val
	if (length(obs) >= 2) {
		out <- stats::approx(yr[obs], val[obs], xout = yr, rule = 1)$y
	}
	# Carry backward from the first anchor.
	out[yr < yr[obs[1]]]           <- val[obs[1]]
	# Carry forward from the last anchor.
	out[yr > yr[obs[length(obs)]]] <- val[obs[length(obs)]]
	out
}

dir.create("data_processed", showWarnings = FALSE)

harmonised_path <- "data_processed/wdi_core_harmonised_long.csv"
indicator_map_path <- "data_raw/wdi/wdi_indicator_map.csv"
country_metadata_path <- "data_raw/wdi/wdi_country_metadata.csv"
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

if (file.exists(country_metadata_path)) {
	country_metadata <- read.csv(country_metadata_path, stringsAsFactors = FALSE) %>%
		transmute(
			iso3c = toupper(trimws(iso3c)),
			wb_region = trimws(region),
			income_group = trimws(income_group),
			income_group_model = dplyr::case_when(
				income_group == "High income" ~ "High income",
				income_group == "Upper middle income" ~ "Upper middle income",
				income_group %in% c("Lower middle income", "Low income") ~ "Lower income",
				TRUE ~ NA_character_
			),
			lending_type = trimws(lending_type)
		) %>%
		distinct(iso3c, .keep_all = TRUE)

	panel <- panel %>%
		left_join(country_metadata, by = "iso3c") %>%
		arrange(iso3c, year)
}

# GCI interpolation and bounded carry rules.
# GCI anchor years are 2020 (scores 0-100) and 2024 (tier midpoints).
# Linearly interpolate gci_overall for 2021-2023, carry 2020 backward to
# earlier panel years, and carry 2024 forward to later panel years.
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

if (all(c("income_group", "income_group_model", "wb_region", "lending_type") %in% names(panel))) {
	metadata_rows <- data.frame(
		variable = c("income_group", "income_group_model", "wb_region", "lending_type"),
		indicator = "WB_COUNTRY_METADATA",
		source = "World Bank country metadata endpoint",
		frequency = "latest available",
		transform = c(
			"none",
			"High income / Upper middle income / Lower income pooled",
			"none",
			"none"
		),
		stringsAsFactors = FALSE
	)

	data_dictionary <- dplyr::bind_rows(data_dictionary, metadata_rows) %>%
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
