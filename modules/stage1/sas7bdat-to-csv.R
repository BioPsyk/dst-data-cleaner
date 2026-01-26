#!/usr/bin/env Rscript

suppressMessages(library(readr))
suppressMessages(library(dplyr))
suppressMessages(library(haven))

usage <- function() {
	message("sas7bdat-to-csv.R [INPUT_FILE] [COLUMNS] [OUTPUT_FILE]")
}

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 3) {
	usage()
	stop("Not enough arguments given, expected 4 arguments");
}

input_file  <- args[1]
columns     <- strsplit(args[2], ",")
columns     <- unlist(columns, use.names=FALSE)
output_file <- args[3]

input_dt <- read_sas(
  input_file,
  col_select   = any_of(columns),
  .name_repair = "unique",
  encoding     = "latin1"
) |>
  relocate(any_of(columns)) |>
  mutate(
    source_file = basename(input_file)
  )

write_csv(input_dt, output_file)
