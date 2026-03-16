#!/usr/bin/env Rscript

#---------------------------------------------------------------------------------

suppressMessages(library(data.table))
suppressMessages(library(dplyr))
suppressMessages(library(dtplyr))
suppressMessages(library(haven))
suppressMessages(library(readr))
suppressMessages(library(stringr))
suppressMessages(library(tools))

#---------------------------------------------------------------------------------
# CLI arguments handling

usage <- function() {
	message("derive-employment-dataset.R [OUTPUT_PREFIX] [INPUT_FILES...]")
}

args <- commandArgs(trailingOnly = TRUE)

exp_args <- 2

if (length(args) < exp_args) {
	usage()
	stop("Expected at least ", exp_args, " arguments");
}

output_prefix <- args[1]

output_path          <- paste0(output_prefix, ".csv")
output_metadata_path <- paste0(output_prefix, "_metadata.json")

#---------------------------------------------------------------------------------
# Reading input files

empty_output <- data.frame(
  person_id        = character(),
  year             = character(),
  status_source    = character(),
  status           = character(),
  industry_source  = character(),
  industry         = character(),
  source_file      = character(),
  stringsAsFactors = FALSE
)

message("[INFO] Writing empty output file '", output_path, "'")

write_csv(empty_output, output_path)

results <- list(
  first_year = "9999-12-31",
  last_year  = "0001-01-01",
  total_rows = 0
)

for(idx in seq(exp_args, length(args), by=1)) {
  input_file <- args[[idx]]

  message("[INFO] Reading input file: ", input_file)

  output <- read_csv(
    input_file,
    show_col_types=FALSE,
    col_types=cols(.default = col_character()),
    col_select=c(
      "PNR",
      "ARBSTIL",
      "NYARB",
      "SOCSTIL_KODE",
      "SOC_STATUS_KODE",
      "BRANCHE_77",
      "BRANCHE_KODE",
      "ARB_HOVED_BRA_DB07",
      "source_file"
    )
  ) |>
    filter(
      PNR != "",
      !is.na(PNR)
    ) |>
    mutate(
      year = str_extract(source_file, "ras([0-9]+).sas7bdat", group = 1),
      status_source = case_when(
        year <= 1993 ~ "ARBSTIL",
        year >= 1994 & year <= 1995 ~ "NYARB",
        year >= 1996 & year <= 2007 ~ "SOCSTIL_KODE",
        .default = "SOC_STATUS_KODE"
      ),
      industry_source = case_when(
        year < 1992 ~ "BRANCHE_77",
        year >= 1992 & year <= 2007 ~ "BRANCHE_KODE",
        .default = "ARB_HOVED_BRA_DB07"
      ),
    ) |>
    rowwise() |>
    mutate(
      status   = cur_data()[[status_source]],
      industry = cur_data()[[industry_source]]
    ) |>
    ungroup() |>
    rename(
      person_id = PNR
    ) |>
    select(any_of(colnames(empty_output))) |>
    relocate(any_of(colnames(empty_output)))

  min_year <- min(output$year)
  max_year <- max(output$year)

  if (min_year < results$first_year) {
    results$first_year <- min_year
  }

  if (max_year > results$last_year) {
    results$last_year <- max_year
  }

  results$total_rows <- results$total_rows + nrow(output)

  message("[INFO] Appending ", nrow(output), " rows to output file '", output_path, "'")

  write_csv(output, output_path, append=TRUE)
}

#---------------------------------------------------------------------------------
# Outputting employment dataset


message("[INFO] Writing metadata to file: \"", output_metadata_path, "\"")

metadata <- list(
  key         = basename(output_prefix),
  title       = "employment",
  description = sprintf(
    "Contains yearly employment status of every person in the populuation. Contains years %s to %s",
    results$first_year,
    results$last_year
  ),
  file_format = list(
    extension  = "csv",
    type       = "text",
    delimiter  = ",",
    quote      = "\"",
    linebreaks = "\n"
  ),
  size = results$total_rows,
  sorted_by = list("person_id"),
  columns = list(
    person_id = list(
      index = 0,
      title = "Unique person ID",
      description = "Unique (population wide) ID of the person, which is an anonymized version of the persons CPR number.",
      examples = list(
        "",
        "846315",
        "0077131291838"
      ),
      type = "string",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:RAS:PNR"
        )
      )
    ),
    year = list(
      index = 1,
      title = "Employment status year",
      description = "The year that the employment status is for. This year is derived from the name of the source file.",
      examples = list(
        "1981",
        "2002",
        "2020"
      ),
      type = "integer",
      nullable = FALSE
    ),
    status_source = list(
      index = 2,
      title = "Status source column",
      description = "In the original dataset 4 different columns were used to represent the employment status. This column contains the name of original column that the status was extracted from.",
      examples = list(
        "ARBSTIL",
        "NYARB",
        "SOCSTIL_KODE",
        "SOC_STATUS_KODE"
      ),
      type = "string",
      nullable = FALSE
    ),
    status = list(
      index = 3,
      title = "Employment status",
      description = "A code that represents the employment status of the person for the current year.",
      type = "string",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:RAS:ARBSTIL"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:RAS:NYARB"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:RAS:SOCSTIL_KODE"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:RAS:SOC_STATUS_KODE"
        )
      )
    ),
    industry_source = list(
      index = 4,
      title = "Industry source column",
      description = "In the original dataset 3 different columns were used to represent the industry of the persons employment. This column contains the name of original column that the industry was extracted from.",
      type = "string",
      nullable = FALSE,
      examples = list(
        "BRANCHE_77",
        "BRANCHE_KODE",
        "ARB_HOVED_BRA_DB07"
      )
    ),
    industry = list(
      index = 5,
      title = "Industry of the employment",
      description = "A code that represents which industry the person was working in for the current year.",
      type = "number",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:RAS:BRANCHE_77"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:RAS:BRANCHE_KODE"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:RAS:ARB_HOVED_BRA_DB07"
        )
      )
    ),
    source_file = list(
      index = 6,
      title = "Source dataset file",
      description = "Name of the dataset file that this row originates from.",
      type = "string",
      nullable = FALSE
    )
  )
)

cat(rjson::toJSON(metadata), file = output_metadata_path)

message("[INFO] All done!")
