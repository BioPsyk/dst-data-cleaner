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
	message("derive-family-income-dataset.R [OUTPUT_PREFIX] [INPUT_FILES...]")
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
  family_id           = character(),
  family_kind         = character(),
  tax_year            = character(),
  tax_sum             = character(),
  income_employment   = character(),
  income_social       = character(),
  income_priv_pension = character(),
  income_other        = character(),
  income_sum          = character(),
  source_file         = character(),
  stringsAsFactors    = FALSE
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
      "FAMILIE_ID",
      "FAMTYPE",
      "FAMINDKOMSTIALT_13",
      "FAMERHVERVSINDK_13",
      "FAMOFF_OVERFORSEL_13",
      "FAMPRIVAT_PENSION_13",
      "FAMRESTINDK_13",
      "FAMSKATTOT_13",
      "source_file"
    )
  ) |>
    filter(
      FAMILIE_ID != "",
      !is.na(FAMILIE_ID)
    ) |>
    mutate(
      tax_year = str_extract(source_file, "faik([0-9]+).sas7bdat", group = 1)
    ) |>
    rename(
      family_id           = FAMILIE_ID,
      family_kind         = FAMTYPE,
      tax_sum             = FAMSKATTOT_13,
      income_employment   = FAMERHVERVSINDK_13,
      income_social       = FAMOFF_OVERFORSEL_13,
      income_priv_pension = FAMPRIVAT_PENSION_13,
      income_other        = FAMRESTINDK_13,
      income_sum          = FAMINDKOMSTIALT_13
    ) |> relocate(any_of(colnames(empty_output)))

  min_year <- min(output$tax_year)
  max_year <- max(output$tax_year)

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
# Outputting income dataset


message("[INFO] Writing metadata to file: \"", output_metadata_path, "\"")

metadata <- list(
  key         = basename(output_prefix),
  title       = "income",
  description = sprintf(
    "Contains the yearly income and taxes for family in the population. This means that each family will appear once for every tax year. Contains tax years %s to %s",
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
  sorted_by = list("family_id"),
  columns = list(
    family_id = list(
      index = 0,
      title = "Family ID",
      description = "Unique (population wide) ID of the family.",
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
          target = "urn:column:dst:FAIK:PNR"
        )
      )
    ),
    family_kind = list(
      index = 1,
      title = "Family kind code",
      description = "Code that represents the kind of family.",
      examples = list(
        "1",
        "3",
        "6"
      ),
      type = "integer",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:FAIK:FAMTYPE"
        )
      )
    ),
    tax_year = list(
      index = 2,
      title = "Tax year",
      description = "The year that the income and taxes are for.",
      examples = list(
        "1981",
        "2002",
        "2020"
      ),
      type = "integer",
      nullable = FALSE
    ),
    tax_sum = list(
      index = 3,
      title = "Tax sum",
      description = "The total sum of taxes payed by the family for the tax year.",
      type = "integer",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:FAIK:FAMSKATTOT_13"
        )
      )
    ),
    income_employment = list(
      index = 4,
      title = "Income from employment",
      description = "Total income derived from employment",
      type = "number",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:FAIK:FAMERHVERVSINDK_13"
        )
      )
    ),
    income_social = list(
      index = 5,
      title = "Income from social security",
      description = "Total income derived from social security",
      type = "number",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:FAIK:FAMOFF_OVERFORSEL_13"
        )
      )
    ),
    income_priv_pension = list(
      index = 6,
      title = "Income from private pension",
      description = "Total income derived from private pension",
      type = "number",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:FAIK:FAMPRIVAT_PENSION_13"
        )
      )
    ),
    income_other = list(
      index = 7,
      title = "Income from other sources",
      description = "Total income derived from other sources than employment, social and private pension.",
      type = "number",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:FAIK:FAMRESTINDK_13"
        )
      )
    ),
    income_sum = list(
      index = 8,
      title = "Income sum",
      description = "Total income from all income sources.",
      type = "number",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:FAIK:FAMINDKOMSTIALT_13"
        )
      )
    ),
    source_file = list(
      index = 9,
      title = "Source dataset file",
      description = "Name of the dataset file that this row originates from.",
      type = "string",
      nullable = FALSE
    )
  )
)

cat(rjson::toJSON(metadata), file = output_metadata_path)

message("[INFO] All done!")
