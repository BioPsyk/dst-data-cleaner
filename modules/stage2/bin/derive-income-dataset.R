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
	message("derive-income-dataset.R [OUTPUT_PREFIX] [INPUT_FILES...]")
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
  person_id           = character(),
  tax_year            = character(),
  tax_scope           = character(),
  tax_sum             = character(),
  income_main_source  = character(),
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
      "PNR",
      "BESKST13",
      "OMFANG",
      "PERINDKIALT_13",
      "ERHVERVSINDK_13",
      "OFF_OVERFORSEL_13",
      "PRIVAT_PENSION_13",
      "RESUINK_13",
      "SKATTOT_13",
      "source_file"
    )
  ) |>
    filter(
      PNR != "",
      !is.na(PNR)
    ) |>
    mutate(
      tax_year = str_extract(source_file, "ind([0-9]+).sas7bdat", group = 1)
    ) |>
    rename(
      person_id           = PNR,
      tax_scope           = OMFANG,
      tax_sum             = SKATTOT_13,
      income_main_source  = BESKST13,
      income_employment   = ERHVERVSINDK_13,
      income_social       = OFF_OVERFORSEL_13,
      income_priv_pension = PRIVAT_PENSION_13,
      income_other        = RESUINK_13,
      income_sum          = PERINDKIALT_13
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
    "Contains the yearly income and taxes for each person in the population. This means that each person will appear once for every tax year. Contains tax years %s to %s",
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
          target = "urn:column:dst:IND:PNR"
        )
      )
    ),
    tax_year = list(
      index = 1,
      title = "tax_year",
      description = "The year that the income and taxes are for.",
      examples = c(
        "1981",
        "2002",
        "2020"
      ),
      type = "integer",
      nullable = FALSE
    ),
    tax_scope = list(
      index = 2,
      title = "tax_scope",
      description = "A code that represents the scope of the persons tax liability. For example, if you are employed and living in Denmark you have full tax liability. If you live abroad but work in Denmark occasionally, you might have reduced tax liability. Tax liability is connected to how much a person benefits from social security. There are 7 distinct codes.",
      examples = c(
        "0",
        "5",
        "9"
      ),
      type = "integer",
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:IND:OMFANG"
        )
      )
    ),
    tax_sum = list(
      index = 3,
      title = "tax_sum",
      description = "The total sum of taxes payed by the person for the tax year.",
      type = "integer",
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:IND:SKATTOT_13"
        )
      )
    ),
    income_main_source = list(
      index = 4,
      title = "income_main_source",
      description = "A code that represents the persons main source of income. For example, if the person was employed, was on benefits or was retired. There are 13 codes.",
      type = "string",
      nullable = FALSE,
      examples = c(
        "01",
        "05",
        "99"
      ),
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:IND:BESKST13"
        )
      )
    ),
    income_employment = list(
      index = 5,
      title = "income_employment",
      description = "Total income derived from employment",
      type = "number",
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:IND:ERHVERVSINDK_13"
        )
      )
    ),
    income_social = list(
      index = 6,
      title = "income_social",
      description = "Total income derived from social security",
      type = "number",
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:IND:OFF_OVERFORSEL_13"
        )
      )
    ),
    income_priv_pension = list(
      index = 7,
      title = "income_priv_pension",
      description = "Total income derived from private pension",
      type = "number",
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:IND:PRIVAT_PENSION_13"
        )
      )
    ),
    income_other = list(
      index = 8,
      title = "income_other",
      description = "Total income derived from other sources than employment, social and private pension.",
      type = "number",
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:IND:RESUINK_13"
        )
      )
    ),
    income_sum = list(
      index = 9,
      title = "income_sum",
      description = "Total income from all income sources.",
      type = "number",
      nullable = FALSE,
      relations = c(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:IND:PERINDKIALT_13"
        )
      )
    ),
    source_file = list(
      index = 10,
      title = "source_file",
      description = "Name of the dataset file that this row originates from.",
      type = "string",
      nullable = FALSE
    )
  )
)

cat(rjson::toJSON(metadata), file = output_metadata_path)

message("[INFO] All done!")
