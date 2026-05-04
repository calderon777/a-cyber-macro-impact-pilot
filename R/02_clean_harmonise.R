suppressPackageStartupMessages({
	library(dplyr)
	library(countrycode)
	library(janitor)
})

dir.create("data_processed", showWarnings = FALSE)

raw_path <- "data_raw/wdi/wdi_core_long.csv"
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
