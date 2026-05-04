suppressPackageStartupMessages({
	library(dplyr)
	library(arrow)
})

dir.create("data_processed", showWarnings = FALSE)

message("Build-panel step scaffold ready.")
message("TODO: Merge harmonised inputs into panel_country_year.parquet and data_dictionary.csv.")

# Expected outputs
# data_processed/panel_country_year.parquet
# data_processed/data_dictionary.csv
