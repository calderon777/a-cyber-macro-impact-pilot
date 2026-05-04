suppressPackageStartupMessages({
	library(dplyr)
	library(ggplot2)
	library(arrow)
})

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

message("Figures step scaffold ready.")
message("TODO: Produce partial-correlation scatter and event-study coefficient plot.")
