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
	message("derive-population-dataset.R [OUTPUT_PREFIX] [INPUT_FILES...]")
}

args <- commandArgs(trailingOnly = TRUE)

exp_args <- 2

if (length(args) < exp_args) {
	usage()
	stop("Expected at least ", exp_args, " arguments");
}

output_prefix <- args[1]

#---------------------------------------------------------------------------------
# Reading input files

input_files <- list()

first_year <- 9999
last_year  <- 0

# Input files are given in the format "[YEAR]:[PATH]",
# therefor we need to parse each argument and separate the year and file path.
# We then put the filepaths into a named list, where the names are the years and
# the values are the filepaths.
for(idx in range(exp_args, length(args))) {
  parts <- str_split(args[idx], ":")
  year  <- parts[[1]][1]
  fpath <- parts[[1]][2]

  input_files[[year]] = fpath

  if (year < first_year) {
    first_year <- year
  }

  if (year > last_year) {
    last_year <- year
  }
}

# We sort the years in decreasing order (latest year first).
years_desc <- str_sort(names(input_files), decreasing = TRUE, numeric = TRUE)

population <- NULL

results <- list(
  first_year = "9999-12-31",
  last_year  = "0001-01-01"
)

for (year in years_desc) {
  input_file <- input_files[[year]]

  message("[INFO] Reading input file: ", input_file)

  input_rows <- fread(
    input_file,
    select=c(
      "PNR",
      "KOEN",
      "FOED_DAG",
      "FOEDREG_KODE",
      "MOR_ID",
      "FAR_ID",
      "FAMILIE_ID",
      "source_file"
    )
  ) |>
    rename(
      person_id     = PNR,
      gender        = KOEN,
      born_at       = FOED_DAG,
      birthplace_id = FOEDREG_KODE,
      mother_id     = MOR_ID,
      father_id     = FAR_ID,
      family_id     = FAMILIE_ID,
    ) |>
    mutate(
      gender = ifelse(gender == "1", "m", "f")
    )

  min_year <- min(input_rows$born_at)
  max_year <- max(input_rows$born_at)

  if (min_year < results$first_year) {
    results$first_year <- min_year
  }

  if (max_year > results$last_year) {
    results$last_year <- max_year
  }

  if (is.null(population)) {
    population <- input_rows
    next
  }

  population <- bind_rows(
    population,
    input_rows |> filter(!(person_id %in% population$person_id))
  )
}

#---------------------------------------------------------------------------------
# Outputting population dataset

output_file          <- paste0(output_prefix, ".csv")
output_metadata_file <- paste0(output_prefix, "_metadata.json")

message("[INFO] Writing data to file: \"", output_file, "\"")

fwrite(as.data.table(population), output_file)

message("[INFO] Writing metadata to file: \"", output_metadata_file, "\"")

metadata <- list(
  key         = basename(output_prefix),
  title       = "population",
  description = sprintf(
    "Contains every person registered in the Danish Civil Registration System in the period %s to %s.
Every person appears once in this dataset, with an unique value in the `person_id` column.",
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
  size = nrow(population),
  sorted_by = c("person_id"),
  columns = list(
    person_id = list(
      index = 0,
      title = "person_id",
      description = "Unique (population wide) ID of the person",
      examples = c(
        "",
        "846315",
        "0077131291838"
      ),
      type = "string",
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:BEF:PNR"
        )
      )
    ),
    gender = list(
      index = 1,
      title = "gender",
      description = "Gender of the person",
      type = "string",
      enum = c(
        list(
          value       = "m",
          description = "Male"
        ),
        list(
          value       = "f",
          description = "Female"
        )
      ),
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:BEF:KOEN"
        )
      )
    ),
    born_at = list(
      index = 2,
      title = "born_at",
      description = "Birthdate of person, in the format YYYY-MM-DD.",
      type = "string",
      format = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
      examples = c(
        "1964-05-01",
        "2001-11-20"
      ),
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:BEF:FOED_DAG"
        )
      )
    ),
    birthplace_id = list(
      index = 3,
      title = "birthplace_id",
      description = "ID of the location where the person was born.
A location can either be:
- A country
- A location/authority inside Denmark (municipality, state office, church, church district or region)
- A location/authority inside Greenland (municipality, state office, church, church district or region)
- Unknown",
      type = "integer",
      examples = c(
        "5154",
        ""
      ),
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:BEF:FOEDREG_KODE"
        ),
        list(
          kind   = "enum_of",
          target = "urn:code:dst:FOEDREG_KODE"
        )
      )
    ),
    mother_id = list(
      index = 4,
      title = "mother_id",
      description = "ID of the persons mother (legal, not biological).",
      type = "string",
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:BEF:MOR_ID"
        )
      )
    ),
    father_id = list(
      index = 5,
      title = "father_id",
      description = "ID of the persons father (legal, not biological).",
      type = "string",
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:BEF:FAR_ID"
        )
      )
    ),
    family_id = list(
      index = 6,
      title = "family_id",
      description = "ID of the family that the person belongs to.",
      type = "string",
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:BEF:FAMILIE_ID"
        )
      )
    ),
    source_file = list(
      index = 7,
      title = "source_file",
      description = "Name of the dataset file that this row originates from.",
      type = "string",
      nullable = FALSE
    )
  )
)

cat(rjson::toJSON(metadata), file = output_metadata_file)

message("[INFO] All done!")
