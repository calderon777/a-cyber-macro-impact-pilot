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

skip_wdi_refresh <- fetch_start_year > end_year

if (skip_wdi_refresh) {
	message(
		"No new WDI years to fetch. Latest local year is ",
		max_year,
		"; current year is ",
		end_year,
		"."
	)
	message("WDI refresh skipped for this run.")
} else {
	message("WDI refresh window: ", fetch_start_year, " to ", end_year)
}

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

years_to_fetch <- if (skip_wdi_refresh) integer(0) else fetch_start_year:end_year
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

# -----------------------------------------------------------------------------
# World Bank country metadata for fixed grouping variables
# -----------------------------------------------------------------------------

country_metadata_path <- "data_raw/wdi/wdi_country_metadata.csv"
country_metadata_log_path <- "data_raw/wdi/wdi_country_metadata_refresh_log.csv"

fetch_wb_country_metadata <- function() {
	url <- "https://api.worldbank.org/v2/country?format=json&per_page=400"

	payload <- jsonlite::fromJSON(
		url,
		simplifyDataFrame = TRUE,
		flatten = TRUE
	)

	if (length(payload) < 2 || is.null(payload[[2]]) || nrow(payload[[2]]) == 0) {
		return(data.frame())
	}

	payload[[2]] %>%
		transmute(
			iso3c = toupper(trimws(id)),
			country = trimws(name),
			region = trimws(region.value),
			admin_region = trimws(adminregion.value),
			income_group = trimws(incomeLevel.value),
			lending_type = trimws(lendingType.value)
		) %>%
		filter(
			!is.na(iso3c),
			grepl("^[A-Z]{3}$", iso3c),
			!tolower(region) %in% c("aggregates", "not classified"),
			!tolower(income_group) %in% c("aggregates", "not classified")
		) %>%
		distinct(iso3c, .keep_all = TRUE) %>%
		arrange(iso3c)
}

country_metadata <- tryCatch(
	fetch_wb_country_metadata(),
	error = function(e) {
		message("World Bank country metadata fetch skipped: ", conditionMessage(e))
		data.frame()
	}
)

if (nrow(country_metadata) > 0) {
	write.csv(country_metadata, country_metadata_path, row.names = FALSE)

	country_metadata_log <- data.frame(
		refreshed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
		source = "https://api.worldbank.org/v2/country?format=json&per_page=400",
		rows_after_cleaning = nrow(country_metadata),
		stringsAsFactors = FALSE
	)

	if (file.exists(country_metadata_log_path)) {
		old_country_metadata_log <- read.csv(country_metadata_log_path, stringsAsFactors = FALSE)
		country_metadata_log <- bind_rows(old_country_metadata_log, country_metadata_log)
	}

	write.csv(country_metadata_log, country_metadata_log_path, row.names = FALSE)
	message("World Bank country metadata refresh complete.")
	message("Country metadata rows stored: ", nrow(country_metadata))
} else if (!file.exists(country_metadata_path)) {
	message("No country metadata file available; income-group heterogeneity will be skipped until metadata is fetched.")
}

# -----------------------------------------------------------------------------
# Optional GCI ingestion (ITU epublications translation payload)
# -----------------------------------------------------------------------------

gci_lang <- Sys.getenv("GCI_LANG", unset = "en")
gci_out <- "data_raw/itu/gci_country_year.csv"
gci_log <- "data_raw/itu/gci_refresh_log.csv"

# Default backfill specs: 2024 tier model + 2020 global score/rank table.
gci_specs <- data.frame(
	slug = c(
		"global-cybersecurity-index-2024",
		"d-str-gci.01-2021-htm-e"
	),
	year = c(2024L, 2020L),
	parser = c("tier", "score_rank"),
	stringsAsFactors = FALSE
)

repair_split_country_names <- function(x) {
	if (length(x) == 0) {
		return(x)
	}

	suffix_tokens <- c("of the)", "State of)", "the Grenadines", "Korea")
	out <- character(0)

	for (token in x) {
		cur <- trimws(token)
		if (!nzchar(cur)) {
			next
		}

		if (length(out) > 0 && cur %in% suffix_tokens) {
			out[length(out)] <- paste(out[length(out)], cur)
		} else {
			out <- c(out, cur)
		}
	}

	out
}

normalize_country_name <- function(x) {
	x <- trimws(x)
	x <- gsub("\\s+", " ", x)
	x <- gsub("’", "'", x, fixed = TRUE)

	recode <- c(
		"Dem. Rep. of the Congo" = "Democratic Republic of the Congo",
		"Congo (Rep. of the)" = "Republic of the Congo",
		"Dominican Rep." = "Dominican Republic",
		"Iran (Islamic Republic of)" = "Iran",
		"Korea (Republic of)" = "Korea, Rep.",
		"Dem. People's Rep. of Korea" = "Korea, Dem. People's Rep.",
		"Lao P.D.R." = "Lao People's Democratic Republic",
		"Nepal (Republic of)" = "Nepal",
		"State of Palestine" = "Palestine",
		"Turkiye" = "Turkey",
		"Türkiye" = "Turkey",
		"Viet Nam" = "Vietnam",
		"Cabo Verde" = "Cape Verde",
		"Russian Federation" = "Russia",
		"Micronesia" = "Micronesia, Fed. Sts.",
		"Vatican" = "Holy See",
		"Iceland of the)" = "Iceland",
		"Lao P.D.R. the Grenadines" = "Lao People's Democratic Republic",
		"Bolivia (Plurinational" = "Bolivia"
	)

	if (x %in% names(recode)) {
		x <- unname(recode[[x]])
	}

	x
}

extract_tier_countries <- function(html, start_pat, end_pat) {
	block_match <- regexpr(
		paste0(start_pat, "[\\s\\S]*?", end_pat),
		html,
		perl = TRUE
	)

	if (block_match[1] == -1) {
		return(character(0))
	}

	block <- regmatches(html, block_match)
	entries <- gregexpr("<p class=\\\"Table-text-small[^>]*>([^<]+)</p>", block, perl = TRUE)
	raw_tags <- regmatches(block, entries)[[1]]
	if (length(raw_tags) == 0) {
		return(character(0))
	}

	raw_values <- sub("^.*?>", "", raw_tags)
	raw_values <- sub("</p>$", "", raw_values)
	raw_values <- gsub("&amp;", "&", raw_values, fixed = TRUE)
	raw_values <- trimws(raw_values)
	raw_values <- raw_values[nzchar(raw_values)]

	repair_split_country_names(raw_values)
}

safe_fetch_gci <- function(slug, lang) {
	gci_translation_url <- sprintf(
		"https://www.itu.int/epublications/api/v1/translation/%s/%s",
		slug,
		lang
	)

	setTimeLimit(elapsed = 120, transient = TRUE)
	on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE), add = TRUE)

	jsonlite::fromJSON(gci_translation_url, simplifyVector = FALSE)
}

extract_score_rank_2020 <- function(html) {
	block_match <- regexpr(
		"<p class=\\\"Table-title\\\">Table 3: GCI results: Global score and rank</p>[\\s\\S]*?</table>",
		html,
		perl = TRUE
	)

	if (block_match[1] == -1) {
		return(data.frame())
	}

	block <- regmatches(html, block_match)
	row_matches <- regmatches(
		block,
		gregexpr("<tr class=\\\"Colored-with-white-lines-6pt[\\s\\S]*?</tr>", block, perl = TRUE)
	)[[1]]

	if (length(row_matches) == 0) {
		return(data.frame())
	}

	parsed <- lapply(row_matches, function(row_html) {
		country_hit <- regmatches(
			row_html,
			regexpr("<p class=\\\"Table-text ParaOverride-4\\\">([^<]+)</p>", row_html, perl = TRUE)
		)

		if (length(country_hit) == 0 || !nzchar(country_hit)) {
			return(NULL)
		}

		country <- sub(
			"^<p class=\\\"Table-text ParaOverride-4\\\">([^<]+)</p>$",
			"\\1",
			country_hit,
			perl = TRUE
		)

		value_hits <- regmatches(
			row_html,
			gregexpr("<p class=\\\"Table-text-centred ParaOverride-1\\\">([^<]+)</p>", row_html, perl = TRUE)
		)[[1]]

		if (length(value_hits) < 2) {
			return(NULL)
		}

		v1 <- sub(
			"^<p class=\\\"Table-text-centred ParaOverride-1\\\">([^<]+)</p>$",
			"\\1",
			value_hits[1],
			perl = TRUE
		)
		v2 <- sub(
			"^<p class=\\\"Table-text-centred ParaOverride-1\\\">([^<]+)</p>$",
			"\\1",
			value_hits[2],
			perl = TRUE
		)

		score <- suppressWarnings(as.numeric(v1))
		rank <- suppressWarnings(as.integer(v2))

		if (is.na(score) || is.na(rank)) {
			return(NULL)
		}

		data.frame(
			country = gsub("\\*+", "", trimws(country)),
			gci_overall = score,
			gci_rank = rank,
			stringsAsFactors = FALSE
		)
	})

	bind_rows(parsed)
}

gci_batches <- list()
gci_refresh_rows <- list()

for (i in seq_len(nrow(gci_specs))) {
	gci_slug <- gci_specs$slug[i]
	gci_year <- as.integer(gci_specs$year[i])
	gci_parser <- gci_specs$parser[i]
	gci_translation_url <- sprintf(
		"https://www.itu.int/epublications/api/v1/translation/%s/%s",
		gci_slug,
		gci_lang
	)

	gci_payload <- tryCatch(
		safe_fetch_gci(gci_slug, gci_lang),
		error = function(e) {
			message("GCI fetch skipped for ", gci_slug, ": ", conditionMessage(e))
			NULL
		}
	)

	if (is.null(gci_payload)) {
		next
	}

	html <- ""
	if (!is.null(gci_payload$content) && length(gci_payload$content) > 0 && !is.null(gci_payload$content[[1]]$html)) {
		html <- gci_payload$content[[1]]$html
	}

	if (!nzchar(html)) {
		message("GCI payload contained no parsable HTML content for ", gci_slug, ".")
		next
	}

	if (gci_parser == "tier") {
		tier_1 <- extract_tier_countries(
			html,
			"<p class=\\\"Heading_bcolor\\\">Tier 1",
			"<p class=\\\"Heading_bcolor\\\">Tier 2"
		)
		tier_2 <- extract_tier_countries(
			html,
			"<p class=\\\"Heading_bcolor\\\">Tier 2",
			"<p class=\\\"Heading_bcolor\\\">Tier 3"
		)
		tier_3 <- extract_tier_countries(
			html,
			"<p class=\\\"Heading_bcolor\\\">Tier 3",
			"<p class=\\\"Heading_bcolor\\\">Tier 4"
		)
		tier_4 <- extract_tier_countries(
			html,
			"<p class=\\\"Heading_bcolor\\\">Tier 4",
			"<p class=\\\"Heading_bcolor\\\">Tier 5"
		)
		tier_5 <- extract_tier_countries(
			html,
			"<p class=\\\"Heading_bcolor\\\">Tier 5",
			"<h3 id=\\\"_idParaDest-14\\\""
		)

		gci_parsed <- bind_rows(
			data.frame(country = tier_1, gci_tier = 1L, stringsAsFactors = FALSE),
			data.frame(country = tier_2, gci_tier = 2L, stringsAsFactors = FALSE),
			data.frame(country = tier_3, gci_tier = 3L, stringsAsFactors = FALSE),
			data.frame(country = tier_4, gci_tier = 4L, stringsAsFactors = FALSE),
			data.frame(country = tier_5, gci_tier = 5L, stringsAsFactors = FALSE)
		) %>%
			mutate(
				gci_overall = dplyr::case_when(
					gci_tier == 1L ~ 97.5,
					gci_tier == 2L ~ 90.0,
					gci_tier == 3L ~ 70.0,
					gci_tier == 4L ~ 37.5,
					gci_tier == 5L ~ 10.0,
					TRUE ~ NA_real_
				),
				gci_rank = NA_integer_
			)
	} else if (gci_parser == "score_rank") {
		gci_parsed <- extract_score_rank_2020(html) %>%
			mutate(gci_tier = NA_integer_)
	} else {
		message("Unsupported GCI parser '", gci_parser, "' for slug ", gci_slug, ".")
		next
	}

	gci_raw <- gci_parsed %>%
		mutate(
			country = vapply(country, normalize_country_name, FUN.VALUE = character(1)),
			iso3c = countrycode::countrycode(country, origin = "country.name", destination = "iso3c", warn = FALSE),
			year = gci_year,
			source_slug = gci_slug
		) %>%
		filter(!is.na(iso3c), !is.na(year), !is.na(gci_overall)) %>%
		distinct(iso3c, year, .keep_all = TRUE) %>%
		arrange(iso3c, year)

	if (nrow(gci_raw) == 0) {
		message("GCI ingestion produced zero mapped rows for ", gci_slug, ".")
		next
	}

	gci_batches[[length(gci_batches) + 1L]] <- gci_raw
	gci_refresh_rows[[length(gci_refresh_rows) + 1L]] <- data.frame(
		refreshed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
		source = gci_translation_url,
		source_slug = gci_slug,
		parser = gci_parser,
		year = gci_year,
		rows_after_cleaning = nrow(gci_raw),
		stringsAsFactors = FALSE
	)
}

if (length(gci_batches) == 0) {
	message("No GCI editions produced rows this run.")
} else {
	gci_raw_all <- bind_rows(gci_batches) %>%
		distinct(iso3c, year, .keep_all = TRUE) %>%
		arrange(iso3c, year)

	if (file.exists(gci_out)) {
		existing_gci <- read.csv(gci_out, stringsAsFactors = FALSE)
		existing_gci$year <- as.integer(existing_gci$year)
	} else {
		existing_gci <- data.frame(
			iso3c = character(),
			country = character(),
			gci_tier = integer(),
			gci_overall = numeric(),
			gci_rank = integer(),
			year = integer(),
			source_slug = character(),
			stringsAsFactors = FALSE
		)
	}

	batch_append_counts <- integer(length(gci_batches))
	for (j in seq_along(gci_batches)) {
		append_piece <- anti_join(
			gci_batches[[j]],
			existing_gci %>% select(iso3c, year),
			by = c("iso3c", "year")
		)

		batch_append_counts[j] <- nrow(append_piece)

		if (nrow(append_piece) > 0) {
			existing_gci <- bind_rows(existing_gci, append_piece) %>%
				arrange(iso3c, year)
		}
	}

	gci_final <- existing_gci %>%
		distinct(iso3c, year, .keep_all = TRUE) %>%
		arrange(iso3c, year)
	gci_rows_appended <- sum(batch_append_counts)

	write.csv(gci_final, gci_out, row.names = FALSE)

	gci_refresh <- bind_rows(gci_refresh_rows) %>%
		mutate(
			rows_appended = batch_append_counts,
			total_rows_after_write = nrow(gci_final)
		)

	if (file.exists(gci_log)) {
		old_gci_log <- read.csv(gci_log, stringsAsFactors = FALSE)
		gci_refresh <- bind_rows(old_gci_log, gci_refresh)
	}

	write.csv(gci_refresh, gci_log, row.names = FALSE)

	message("GCI refresh complete.")
	message("Rows appended this run (GCI): ", gci_rows_appended)
	message("Total GCI rows stored: ", nrow(gci_final))
}

# -----------------------------------------------------------------------------
# Optional incidents ingestion (open CSV URL or local CSV source)
# -----------------------------------------------------------------------------

incidents_url <- Sys.getenv("INCIDENTS_CSV_URL", unset = "")
incidents_local_source <- "data_raw/incidents/incidents_source.csv"
incidents_raw_cache <- "data_raw/incidents/incidents_source_cached.csv"
incidents_out <- "data_raw/incidents/incidents_country_year.csv"
incidents_log <- "data_raw/incidents/incidents_refresh_log.csv"

resolve_incident_col <- function(nm, candidates) {
	idx <- which(tolower(nm) %in% tolower(candidates))
	if (length(idx) == 0) {
		return(NA_character_)
	}
	nm[idx[1]]
}

read_incidents_source <- function() {
	if (nzchar(incidents_url)) {
		message("Downloading incidents source from INCIDENTS_CSV_URL...")
		dat <- tryCatch(
			read.csv(incidents_url, stringsAsFactors = FALSE),
			error = function(e) {
				stop("Failed to read INCIDENTS_CSV_URL: ", conditionMessage(e))
			}
		)
		write.csv(dat, incidents_raw_cache, row.names = FALSE)
		return(dat)
	}

	if (file.exists(incidents_local_source)) {
		message("Using local incidents source: ", incidents_local_source)
		return(read.csv(incidents_local_source, stringsAsFactors = FALSE))
	}

	return(NULL)
}

incidents_src <- read_incidents_source()

if (is.null(incidents_src)) {
	message("No incidents source found. Set INCIDENTS_CSV_URL or provide data_raw/incidents/incidents_source.csv.")
} else {
	nm <- names(incidents_src)
	iso_col <- resolve_incident_col(nm, c("iso3c", "country_iso3", "country_code", "target_iso3", "iso"))
	country_col <- resolve_incident_col(nm, c("country", "country_name", "target_country"))
	year_col <- resolve_incident_col(nm, c("year", "event_year", "date_year"))
	count_col <- resolve_incident_col(nm, c("incidents", "incident_count", "count", "events"))

	if (is.na(year_col) || is.na(count_col) || (is.na(iso_col) && is.na(country_col))) {
		stop(
			"Incidents source must include year and incident count columns plus iso3c or country column. ",
			"Detected columns: ",
			paste(nm, collapse = ", ")
		)
	}

	incidents_clean <- incidents_src %>%
		transmute(
			iso3c = if (!is.na(iso_col)) toupper(trimws(.data[[iso_col]])) else NA_character_,
			country = if (!is.na(country_col)) trimws(.data[[country_col]]) else NA_character_,
			year = suppressWarnings(as.integer(.data[[year_col]])),
			cyber_incidents = suppressWarnings(as.numeric(.data[[count_col]]))
		) %>%
		mutate(
			iso3c_from_country = if_else(
				is.na(iso3c) | !grepl("^[A-Z]{3}$", iso3c),
				countrycode::countrycode(country, origin = "country.name", destination = "iso3c", warn = FALSE),
				iso3c
			),
			iso3c = if_else(!is.na(iso3c) & grepl("^[A-Z]{3}$", iso3c), iso3c, iso3c_from_country)
		) %>%
		select(iso3c, country, year, cyber_incidents) %>%
		filter(!is.na(iso3c), !is.na(year), !is.na(cyber_incidents)) %>%
		group_by(iso3c, year) %>%
		summarise(
			country = dplyr::first(na.omit(country)),
			cyber_incidents = sum(cyber_incidents, na.rm = TRUE),
			.groups = "drop"
		) %>%
		mutate(cyber_incidents_log = log1p(cyber_incidents)) %>%
		arrange(iso3c, year)

	if (file.exists(incidents_out)) {
		existing_incidents <- read.csv(incidents_out, stringsAsFactors = FALSE)
		existing_incidents$year <- as.integer(existing_incidents$year)
		append_inc <- anti_join(
			incidents_clean,
			existing_incidents %>% select(iso3c, year),
			by = c("iso3c", "year")
		)
		incidents_final <- bind_rows(existing_incidents, append_inc) %>%
			arrange(iso3c, year)
		rows_appended_inc <- nrow(append_inc)
	} else {
		incidents_final <- incidents_clean
		rows_appended_inc <- nrow(incidents_clean)
	}

	write.csv(incidents_final, incidents_out, row.names = FALSE)

	inc_log <- data.frame(
		refreshed_at_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
		source = if (nzchar(incidents_url)) incidents_url else incidents_local_source,
		rows_in_source = nrow(incidents_src),
		rows_after_cleaning = nrow(incidents_clean),
		rows_appended = rows_appended_inc,
		total_rows_after_write = nrow(incidents_final),
		stringsAsFactors = FALSE
	)

	if (file.exists(incidents_log)) {
		old_inc_log <- read.csv(incidents_log, stringsAsFactors = FALSE)
		inc_log <- bind_rows(old_inc_log, inc_log)
	}

	write.csv(inc_log, incidents_log, row.names = FALSE)

	message("Incidents refresh complete.")
	message("Rows appended this run (incidents): ", rows_appended_inc)
	message("Total incidents rows stored: ", nrow(incidents_final))
}
