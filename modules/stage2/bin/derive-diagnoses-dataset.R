#!/usr/bin/env Rscript

#---------------------------------------------------------------------------------

suppressMessages(library(data.table))
suppressMessages(library(dplyr))
suppressMessages(library(dtplyr))
suppressMessages(library(haven))
suppressMessages(library(readr))
suppressMessages(library(stringr))
suppressMessages(library(tools))
suppressMessages(library(rjson))

#---------------------------------------------------------------------------------
# CLI arguments handling

usage <- function() {
	message("derive-diagnoses-population.R [OUTPUT_PREFIX] [DATASETS_FILE]")
}

args <- commandArgs(trailingOnly = TRUE)

exp_args <- 2

if (length(args) < exp_args) {
	usage()
	stop("Expected at least ", exp_args, " arguments");
}

output_prefix <- args[1]
datasets_path <- args[2]

#---------------------------------------------------------------------------------
# Reading input files

message("[INFO] Reading datasets file '", datasets_path, "'")

datasets <- fromJSON(file=datasets_path)

empty_output <- data.frame(
  person_id             = character(),
  record_id             = character(),
  patient_kind          = character(),
  starts_at             = character(),
  ends_at               = character(),
  diagnosis_id          = character(),
  diagnosis_kind        = character(),
  record_source_file    = character(),
  diagnosis_source_file = character(),
  stringsAsFactors      = FALSE
)

output_path <- paste0(output_prefix, ".csv")

message("[INFO] Writing empty output file '", output_path, "'")

write_csv(empty_output, output_path)

processDatasetGroup <- function(results, group, records_columns, diagnoses_columns) {
  periods <- group[["records"]][["periods"]]
  i       <- 0

  records_columns$record_source_file      = "source_file"
  diagnoses_columns$diagnosis_source_file = "source_file"

  for (per in periods) {
    i <- i + 1

    records_path   <- group$records$files[[i]]
    diagnoses_path <- group$diagnoses$files[[i]]

    message("[INFO] Reading records from '", records_path, "'")
    records <- read_csv(
      records_path,
      show_col_types=FALSE,
      col_types=cols(.default = col_character()),
      col_select=any_of(unlist(records_columns, use.names=FALSE))
    ) |> rename(!!!records_columns) |>
      mutate(record_id = as.character(record_id)) |>
      filter(
        record_id != "",
        !is.na(record_id),
        person_id != "",
        !is.na(person_id)
      )

    min_year <- min(records$starts_at)
    max_year <- max(records$ends_at)

    if (!is.na(min_year) && min_year < results$first_year) {
      results$first_year <- min_year
    }

    if (!is.na(max_year) && max_year > results$last_year) {
      results$last_year <- max_year
    }

    message("[INFO] Reading diagnoses from '", records_path, "'")
    diagnoses <- read_csv(
      diagnoses_path,
      show_col_types=FALSE,
      col_types=cols(.default = col_character()),
      col_select=any_of(unlist(diagnoses_columns, use.names=FALSE))
    ) |> rename(!!!diagnoses_columns) |>
      mutate(
        record_id = as.character(record_id)
      ) |>
      filter(
        record_id != "",
        !is.na(record_id)
      )

    output <- inner_join(
      records,
      diagnoses,
      by=join_by(record_id)
    ) |> relocate(any_of(colnames(empty_output)))

    results$total_rows <- results$total_rows + nrow(output)

    message("[INFO] Appending ", nrow(output), " rows to output file '", output_path, "'")

    write_csv(output, output_path, append=TRUE)
  }

  return(results)
}

results <- list(
  total_rows = 0,
  first_year = "9999-12-31",
  last_year  = "0001-01-01"
)

results <- processDatasetGroup(
  results,
  datasets[["pcrr1"]],
  list(
    person_id = "CPRNR",
    record_id = "PAT_SEQ",
    patient_kind = "PTTYPE",
    starts_at = "INDLDATO",
    ends_at = "UDSKDATO"
  ),
  list(
    record_id = "PAT_SEQ",
    diagnosis_id = "HOVEDDIAG",
    diagnosis_kind = "MODIFHD"
  )
)

results <- processDatasetGroup(
  results,
  datasets[["pcrr2"]],
  list(
    person_id = "CPRNR",
    record_id = "PAT_SEQ",
    patient_kind = "PTTYPE",
    starts_at = "INDLDATO",
    ends_at = "UDSKDATO"
  ),
  list(
    record_id = "PAT_SEQ",
    diagnosis_id = "DIAG",
    diagnosis_kind = "DART"
  )
)

results <- processDatasetGroup(
  results,
  datasets[["pcrr3"]],
  list(
    person_id = "PNR",
    record_id = "RECNUM",
    patient_kind = "C_PATTYPE",
    starts_at = "D_INDDTO",
    ends_at = "D_UDDTO"
  ),
  list(
    record_id = "RECNUM",
    diagnosis_id = "C_DIAG",
    diagnosis_kind = "C_DIAGTYPE"
  )
)

results <- processDatasetGroup(
  results,
  datasets[["lpr2"]],
  list(
    person_id = "PNR",
    record_id = "RECNUM",
    patient_kind = "C_PATTYPE",
    starts_at = "D_INDDTO",
    ends_at = "D_UDDTO"
  ),
  list(
    record_id = "RECNUM",
    diagnosis_id = "C_DIAG",
    diagnosis_kind = "C_DIAGTYPE"
  )
)

results <- processDatasetGroup(
  results,
  datasets[["lpr3"]],
  list(
    person_id = "PNR",
    record_id = "DW_EK_KONTAKT",
    patient_kind = "KONTAKTTYPE",
    starts_at = "DATO_START",
    ends_at = "DATO_SLUT"
  ),
  list(
    record_id = "DW_EK_KONTAKT",
    diagnosis_id = "DIAGNOSEKODE",
    diagnosis_kind = "DIAGNOSETYPE"
  )
)

metadata_output_path <- paste0(output_prefix, "_metadata.json")

message("[INFO] Wrote ", results$total_rows, " rows in total")
message("[INFO] Writing metadata to file: \"", metadata_output_path, "\"")

metadata <- list(
  key         = basename(output_prefix),
  title       = "diagnoses",
  description = sprintf(
    "Contains every diagnosis found in NPR and PCRR in the period %s to %s.",
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
  sorted_by = list("person_id", "record_id"),
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
          target = "urn:column:dst:LPR_ADM:PNR"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:PSYK_ADM:PNR"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_F_KONTAKTER:PNR"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:patient_icd8:CPRNR"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:patient_icd10:CPRNR"
        )
      )
    ),
    record_id = list(
      index = 1,
      title = "Medical record ID",
      description = "Unique (register wide) ID of the medical record which the diagnosis belongs to",
      type = "string",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_ADM:RECNUM"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:PSYK_ADM:RECNUM"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_F_KONTAKTER:DW_EK_KONTAKT"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:patient_icd8:PAT_SEQ"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:patient_icd10:PAT_SEQ"
        )
      )
    ),
    patient_kind = list(
      index = 2,
      title = "Patient kind",
      description = "Code for the kind of patient the medical record was created as. Note that different codes were used by the different registers.",
      type = "string",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_ADM:C_PATTYPE"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:PSYK_ADM:C_PATTYPE"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_F_KONTAKTER:KONTAKTTYPE"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:patient_icd8:PTTYPE"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:patient_icd10:PTTYPE"
        )
      )
    ),
    starts_at = list(
      index = 3,
      title = "Medical record start date",
      description = "Starting date of medical record",
      type = "string",
      format = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
      examples = list(
        "1964-05-01",
        "2001-11-20"
      ),
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_ADM:D_INDDTO"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:PSYK_ADM:D_INDDTO"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_F_KONTAKTER:DATO_START"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:patient_icd8:INDLDATO"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:patient_icd10:INDLDATO"
        )
      )
    ),
    ends_at = list(
      index = 4,
      title = "Medical record end date",
      description = "Ending date of medical record",
      type = "string",
      format = "^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
      examples = list(
        "1964-05-01",
        "2001-11-20"
      ),
      nullable = TRUE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_ADM:D_UDDTO"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:PSYK_ADM:D_UDDTO"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_F_KONTAKTER:DATO_SLUT"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:patient_icd8:UDSKDATO"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:patient_icd10:UDSKDATO"
        )
      )
    ),
    diagnosis_id = list(
      index = 5,
      title = "Diagnosis ICD-code",
      description = "SKS-code (D-code) or ICD-8 code for the diagnosis",
      type = "string",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_DIAG:C_DIAG"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:PSYK_DIAG:C_DIAG"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_F_DIAGNOSER:DIAGNOSEKODE"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:patient_icd8:HOVEDDIAG"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:diag_icd10:DIAG"
        )
      )
    ),
    diagnosis_kind = list(
      index = 6,
      title = "Diagnosis kind code",
      description = "Code for the kind of diagnosis made. Note that different codes were used by the different registers.",
      type = "string",
      nullable = FALSE,
      relations = list(
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_DIAG:C_DIAGTYPE"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:PSYK_DIAG:C_DIAGTYPE"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:LPR_F_DIAGNOSER:DIAGNOSETYPE"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:patient_icd8:MODIFHD"
        ),
        list(
          kind   = "originates_from",
          target = "urn:column:dst:diag_icd10:DART"
        )
      )
    ),
    record_source_file = list(
      index = 7,
      title = "Medical record source file",
      description = "Name of the dataset file that the medical record data of this row originates from.",
      type = "string",
      nullable = FALSE
    ),
    diagnosis_source_file = list(
      index = 8,
      title = "Diagnosis source file",
      description = "Name of the dataset file that the diagnosis data of this row originates from.",
      type = "string",
      nullable = FALSE
    )
  )
)

cat(rjson::toJSON(metadata), file = metadata_output_path)

message("[INFO] All done!")
