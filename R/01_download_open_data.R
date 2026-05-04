suppressPackageStartupMessages({
	library(dplyr)
})

dir.create("data_raw", showWarnings = FALSE)
dir.create("data_raw/wdi", recursive = TRUE, showWarnings = FALSE)
dir.create("data_raw/wb_digital", recursive = TRUE, showWarnings = FALSE)
dir.create("data_raw/itu", recursive = TRUE, showWarnings = FALSE)
dir.create("data_raw/incidents", recursive = TRUE, showWarnings = FALSE)

message("Download step scaffold ready.")
message("TODO: Add API and file-download logic for WDI, ITU, and incident sources.")
