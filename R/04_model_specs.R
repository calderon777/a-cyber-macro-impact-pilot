suppressPackageStartupMessages({
	library(dplyr)
	library(fixest)
	library(modelsummary)
	library(arrow)
})

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)

message("Model-spec step scaffold ready.")
message("TODO: Load panel, construct lags, run baseline and robustness FE models.")

# Example model shape
# feols(gdp_growth ~ l1_gci_overall + controls | iso3c + year, data = panel, cluster = ~iso3c)
