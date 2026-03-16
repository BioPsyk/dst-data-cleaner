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
	message("derive-education-dataset.R [OUTPUT_PREFIX] [INPUT_FILES...]")
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
  code             = character(),
  institute        = character(),
  source           = character(),
  ended_at         = character(),
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
      "HFAUDD",
      "HFINSTNR",
      "HF_KILDE",
      "HF_VFRA",
      "source_file"
    )
  ) |>
    rename(
      person_id    = PNR,
      kind         = HFAUDD,
      institute    = HFINSTNR,
      source       = HF_KILDE,
      completed_at = HF_VFRA
    ) |>
    filter(
      person_id != "",
      !is.na(person_id)
    )

  min_year <- min(output$completed_at)
  max_year <- max(output$completed_at)

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
# Outputting education dataset


message("[INFO] Writing metadata to file: \"", output_metadata_path, "\"")

metadata <- list(
  key         = basename(output_prefix),
  title       = "highest_education",
  description = sprintf(
    "Contains every highest education that has been obtained in the period %s to %s.
Each persion can appear multiple times in this dataset, as their highest education is
updated everytime they complete an education program that gives a higher credential
than their previous highest education.",
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
          target = "urn:column:dst:UDDA:PNR"
        )
      )
    ),
    kind = list(
      index = 1,
      title = "Education kind",
      description = "Code that describes the kind of education that was completed. There are 3510 distinct codes.",
      examples = list(
        "1",
        "2462",
        "6200"
      ),
      type = "integer",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:UDDA:HFAUDD"
        )
      )
    ),
    institute = list(
      index = 2,
      title = "Institute code",
      description = "Code of the institute where the education was completed. There are 9330 distinct codes.",
      examples = list(
        "101000",
        "251001",
        "281326"
      ),
      type = "integer",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:UDDA:HFINSTNR"
        )
      )
    ),
    source = list(
      index = 3,
      title = "Source of information code",
      description = "Code that classifies the source of the education information. There 19 distinct codes.",
      examples = list(
        "1",
        "10",
        "19"
      ),
      type = "integer",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:UDDA:HF_KILDE"
        )
      )
    ),
    completed_at = list(
      index = 4,
      title = "Completion date",
      description = "The date when the education was completed.",
      examples = list(
        "1981-01-03",
        "2002-03-13",
        "2021-10-25"
      ),
      type = "string",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:UDDA:HF_VFRA"
        )
      )
    ),
    source_file = list(
      index = 5,
      title = "Source dataset file",
      description = "Name of the dataset file that this row originates from.",
      type = "string",
      nullable = FALSE
    )
  )
)

cat(rjson::toJSON(metadata), file = output_metadata_path)

message("[INFO] All done!")
