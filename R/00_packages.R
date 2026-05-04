# Install and load required packages for the MVP.
required_packages <- c(
	"wbstats", "httr2", "jsonlite", "readxl", "arrow", "janitor",
	"countrycode", "dplyr", "tidyr", "stringr", "fixest", "modelsummary",
	"broom", "ggplot2", "patchwork", "targets"
)

installed <- rownames(installed.packages())
to_install <- setdiff(required_packages, installed)

if (length(to_install) > 0) {
	install.packages(to_install, repos = "https://cloud.r-project.org")
}

invisible(lapply(required_packages, library, character.only = TRUE))
message("Package setup complete.")
