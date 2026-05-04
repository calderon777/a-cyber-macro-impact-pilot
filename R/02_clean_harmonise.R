suppressPackageStartupMessages({
	library(dplyr)
	library(tidyr)
	library(countrycode)
	library(janitor)
})

dir.create("data_processed", showWarnings = FALSE)

raw_path <- "data_raw/wdi/wdi_core_long.csv"
incidents_path <- "data_raw/incidents/incidents_country_year.csv"
gci_path <- "data_raw/itu/gci_country_year.csv"
harmonised_path <- "data_processed/wdi_core_harmonised_long.csv"
audit_path <- "data_processed/wdi_harmonise_audit.csv"

if (!file.exists(raw_path)) {
	stop("Missing raw input file: ", raw_path, ". Run R/01_download_open_data.R first.")
}

raw <- read.csv(raw_path, stringsAsFactors = FALSE) %>%
	janitor::clean_names()

required_cols <- c("iso3c", "country", "year", "indicator", "value", "variable")
missing_cols <- setdiff(required_cols, names(raw))
if (length(missing_cols) > 0) {
	stop("Input file is missing required columns: ", paste(missing_cols, collapse = ", "))
}

harmonised <- raw %>%
	transmute(
		iso3c_raw = toupper(trimws(iso3c)),
		country = trimws(country),
		year = suppressWarnings(as.integer(year)),
		indicator = trimws(indicator),
		variable = trimws(variable),
		value = suppressWarnings(as.numeric(value))
	) %>%
	mutate(
		iso3c_from_country = countrycode(
			country,
			origin = "country.name",
			destination = "iso3c",
			warn = FALSE
		),
		iso3c = if_else(
			!is.na(iso3c_raw) & grepl("^[A-Z]{3}$", iso3c_raw),
			iso3c_raw,
			iso3c_from_country
		)
	) %>%
	filter(!is.na(iso3c), !is.na(year), !is.na(indicator), !is.na(variable)) %>%
	select(iso3c, country, year, indicator, variable, value)

# Keep one row per key. If duplicate rows exist, keep the first non-missing value.
harmonised <- harmonised %>%
	arrange(iso3c, year, indicator, desc(!is.na(value))) %>%
	group_by(iso3c, year, indicator, variable) %>%
	slice(1) %>%
	ungroup()

if (file.exists(incidents_path)) {
	inc_raw <- read.csv(incidents_path, stringsAsFactors = FALSE) %>%
		janitor::clean_names()

	inc_required <- c("iso3c", "year", "cyber_incidents", "cyber_incidents_log")
	inc_missing <- setdiff(inc_required, names(inc_raw))
	if (length(inc_missing) > 0) {
		stop("Incidents file is missing required columns: ", paste(inc_missing, collapse = ", "))
	}

	inc_long <- inc_raw %>%
		transmute(
			iso3c = toupper(trimws(iso3c)),
			country = if ("country" %in% names(inc_raw)) trimws(country) else NA_character_,
			year = suppressWarnings(as.integer(year)),
			cyber_incidents = suppressWarnings(as.numeric(cyber_incidents)),
			cyber_incidents_log = suppressWarnings(as.numeric(cyber_incidents_log))
		) %>%
		tidyr::pivot_longer(
			cols = c(cyber_incidents, cyber_incidents_log),
			names_to = "variable",
			values_to = "value"
		) %>%
		mutate(indicator = "INCIDENTS_OPEN") %>%
		filter(!is.na(iso3c), !is.na(year), !is.na(value)) %>%
		select(iso3c, country, year, indicator, variable, value)

	harmonised <- bind_rows(harmonised, inc_long) %>%
		arrange(iso3c, year, indicator, desc(!is.na(value))) %>%
		group_by(iso3c, year, indicator, variable) %>%
		slice(1) %>%
		ungroup()
}

if (file.exists(gci_path)) {
	gci_raw <- read.csv(gci_path, stringsAsFactors = FALSE) %>%
		janitor::clean_names()

	gci_required <- c("iso3c", "year", "gci_overall")
	gci_missing <- setdiff(gci_required, names(gci_raw))
	if (length(gci_missing) > 0) {
		stop("GCI file is missing required columns: ", paste(gci_missing, collapse = ", "))
	}

	gci_long <- gci_raw %>%
		transmute(
			iso3c = toupper(trimws(iso3c)),
			country = if ("country" %in% names(gci_raw)) trimws(country) else NA_character_,
			year = suppressWarnings(as.integer(year)),
			gci_overall = suppressWarnings(as.numeric(gci_overall)),
			gci_tier = if ("gci_tier" %in% names(gci_raw)) suppressWarnings(as.numeric(gci_tier)) else NA_real_
		) %>%
		tidyr::pivot_longer(
			cols = c(gci_overall, gci_tier),
			names_to = "variable",
			values_to = "value"
		) %>%
		mutate(indicator = "GCI_OPEN") %>%
		filter(!is.na(iso3c), !is.na(year), !is.na(value)) %>%
		select(iso3c, country, year, indicator, variable, value)

	harmonised <- bind_rows(harmonised, gci_long) %>%
		arrange(iso3c, year, indicator, desc(!is.na(value))) %>%
		group_by(iso3c, year, indicator, variable) %>%
		slice(1) %>%
		ungroup()
}

write.csv(harmonised, harmonised_path, row.names = FALSE)

audit <- data.frame(
	rows_raw = nrow(raw),
	rows_harmonised = nrow(harmonised),
	countries_harmonised = dplyr::n_distinct(harmonised$iso3c),
	year_min = min(harmonised$year, na.rm = TRUE),
	year_max = max(harmonised$year, na.rm = TRUE),
	duplicate_keys_remaining = harmonised %>%
		count(iso3c, year, indicator) %>%
		filter(n > 1) %>%
		nrow(),
	stringsAsFactors = FALSE
)

write.csv(audit, audit_path, row.names = FALSE)

message("Harmonisation complete.")
message("Wrote: ", harmonised_path)
message("Wrote: ", audit_path)
