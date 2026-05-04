suppressPackageStartupMessages({
	library(dplyr)
	library(tidyr)
	library(arrow)
})

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

arrow::write_parquet(panel, panel_path)

if (file.exists(indicator_map_path)) {
	indicator_map <- read.csv(indicator_map_path, stringsAsFactors = FALSE)
	data_dictionary <- long_df %>%
		distinct(variable, indicator) %>%
		left_join(indicator_map, by = c("indicator", "variable")) %>%
		transmute(
			variable,
			indicator,
			source = "World Development Indicators",
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
			source = "World Development Indicators",
			frequency = "annual",
			transform = "none"
		) %>%
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
