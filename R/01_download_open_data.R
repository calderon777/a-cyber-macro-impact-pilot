suppressPackageStartupMessages({
	library(dplyr)
	library(jsonlite)
})

# Increase network timeout for API calls on slower or constrained connections.
options(timeout = max(120, getOption("timeout")))

dir.create("data_raw", showWarnings = FALSE)
dir.create("data_raw/wdi", recursive = TRUE, showWarnings = FALSE)
dir.create("data_raw/wb_digital", recursive = TRUE, showWarnings = FALSE)
dir.create("data_raw/itu", recursive = TRUE, showWarnings = FALSE)
dir.create("data_raw/incidents", recursive = TRUE, showWarnings = FALSE)

# Core MVP indicators from the project plan.
indicator_map <- data.frame(
	indicator = c(
		"NY.GDP.MKTP.KD.ZG",  # GDP growth (annual %)
		"SL.GDP.PCAP.EM.KD",  # GDP per person employed
		"NE.GDI.TOTL.ZS",     # Gross capital formation (% of GDP)
		"SL.EMP.TOTL.SP.ZS",  # Employment to population ratio (15+, %)
		"IT.NET.USER.ZS",     # Individuals using the internet (% population)
		"SP.POP.TOTL",        # Population total
		"FP.CPI.TOTL.ZG",     # Inflation, consumer prices (annual %)
		"NE.TRD.GNFS.ZS"      # Trade (% of GDP)
	),
	variable = c(
		"gdp_growth",
		"gdp_per_person_employed",
		"gcf_gdp",
		"employment_ratio",
		"internet_users_pct",
		"population_total",
		"inflation_cpi",
		"trade_gdp"
	),
	stringsAsFactors = FALSE
)

out_path <- "data_raw/wdi/wdi_core_long.csv"
metadata_path <- "data_raw/wdi/wdi_indicator_map.csv"
refresh_log_path <- "data_raw/wdi/wdi_refresh_log.csv"

start_year <- 2014L
# WDI macro indicators are annual; use the latest completed year for stable refreshes.
end_year <- as.integer(format(Sys.Date(), "%Y")) - 1L

if (file.exists(out_path)) {
	existing <- read.csv(out_path, stringsAsFactors = FALSE)
	existing$year <- as.integer(existing$year)
	max_year <- suppressWarnings(max(existing$year, na.rm = TRUE))
	if (!is.finite(max_year)) {
		max_year <- start_year - 1L
	}
	fetch_start_year <- max(max_year + 1L, start_year)
} else {
	existing <- data.frame()
	max_year <- start_year - 1L
	fetch_start_year <- start_year
}

if (fetch_start_year > end_year) {
	message(
		"No new WDI years to fetch. Latest local year is ",
		max_year,
		"; current year is ",
		end_year,
		"."
	)
	if (!file.exists(metadata_path)) {
		write.csv(indicator_map, metadata_path, row.names = FALSE)
	}
	quit(save = "no", status = 0)
}

message("Fetching WDI data for years ", fetch_start_year, " to ", end_year, "...")

# Persist indicator metadata up front so artifact exists even during long bootstrap runs.
write.csv(indicator_map, metadata_path, row.names = FALSE)

safe_fetch_indicator_year <- function(indicator_code, y, retries = 3L) {
	url <- sprintf(
		"https://api.worldbank.org/v2/country/all/indicator/%s?format=json&date=%d:%d&per_page=20000",
		utils::URLencode(indicator_code, reserved = TRUE),
		y,
		y
	)

	attempt <- 1L
	while (attempt <= retries) {
		result <- tryCatch(
			{
				setTimeLimit(elapsed = 120, transient = TRUE)
				payload <- jsonlite::fromJSON(
					url,
					simplifyDataFrame = TRUE,
					flatten = TRUE
				)
				if (length(payload) < 2 || is.null(payload[[2]]) || nrow(payload[[2]]) == 0) {
					return(data.frame())
				}

				dat <- payload[[2]]
				dat %>%
					transmute(
						iso3c = countryiso3code,
						country = country.value,
						year = as.integer(date),
						indicator = indicator_code,
						value = as.numeric(value)
					)
			},
			error = function(e) e,
			finally = {
				setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE)
			}
		)

		if (!inherits(result, "error")) {
			return(result)
		}

		message(
			"Indicator ", indicator_code,
			" year ", y,
			" attempt ", attempt,
			" failed: ", conditionMessage(result)
		)
		attempt <- attempt + 1L
	}

	stop(
		"Failed to fetch indicator ",
		indicator_code,
		" for year ",
		y,
		" after ",
		retries,
		" attempts."
	)
}

if (nrow(existing) == 0) {
	existing <- data.frame(
		iso3c = character(),
		country = character(),
		year = integer(),
		indicator = character(),
		value = numeric(),
		variable = character(),
		stringsAsFactors = FALSE
	)
}

years_to_fetch <- fetch_start_year:end_year
rows_fetched_total <- 0L
rows_appended_total <- 0L
failed_requests <- 0L

for (y in years_to_fetch) {
	message("Fetching year ", y, "...")
	year_rows_list <- list()

	for (ind in indicator_map$indicator) {
		fetched_piece <- tryCatch(
			safe_fetch_indicator_year(ind, y),
			error = function(e) {
				failed_requests <<- failed_requests + 1L
				message(
					"Skipping indicator ", ind,
					" for year ", y,
					" after retries. Error: ",
					conditionMessage(e)
				)
				data.frame()
			}
		)

		if (nrow(fetched_piece) > 0) {
			year_rows_list[[length(year_rows_list) + 1L]] <- fetched_piece
		}
	}

	if (length(year_rows_list) == 0) {
		next
	}

	year_rows <- bind_rows(year_rows_list) %>%
		left_join(indicator_map, by = "indicator") %>%
		filter(!is.na(iso3c), !is.na(year), !is.na(indicator))

	append_year <- anti_join(
		year_rows,
		existing %>% select(iso3c, year, indicator),
		by = c("iso3c", "year", "indicator")
	)

	rows_fetched_total <- rows_fetched_total + nrow(year_rows)
	rows_appended_total <- rows_appended_total + nrow(append_year)

	if (nrow(append_year) > 0) {
		existing <- bind_rows(existing, append_year) %>%
			arrange(iso3c, year, indicator)

		# Checkpoint after each year so bootstrap progress is resumable.
		write.csv(existing, out_path, row.names = FALSE)
	}
}

combined <- existing %>%
	arrange(iso3c, year, indicator)

if (nrow(combined) > 0) {
	write.csv(combined, out_path, row.names = FALSE)
}

write.csv(indicator_map, metadata_path, row.names = FALSE)

refresh_log <- data.frame(
	refreshed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
	fetch_start_year = fetch_start_year,
	fetch_end_year = end_year,
	rows_fetched = rows_fetched_total,
	rows_appended = rows_appended_total,
	failed_requests = failed_requests,
	total_rows_after_write = nrow(combined),
	stringsAsFactors = FALSE
)

if (file.exists(refresh_log_path)) {
	old_log <- read.csv(refresh_log_path, stringsAsFactors = FALSE)
	refresh_log <- bind_rows(old_log, refresh_log)
}

write.csv(refresh_log, refresh_log_path, row.names = FALSE)

message("WDI refresh complete.")
message("Rows fetched this run: ", rows_fetched_total)
message("Rows appended this run: ", rows_appended_total)
message("Indicator-year requests failed after retries: ", failed_requests)
message("Total rows stored: ", nrow(combined))
