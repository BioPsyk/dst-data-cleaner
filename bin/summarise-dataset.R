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
	message("summarise-dataset.R [INPUT_FILE] [OUTPUT_FILE]")
}

args <- commandArgs(trailingOnly = TRUE)

exp_args <- 3

if (length(args) != exp_args) {
	usage()
	stop("Expected at least ", exp_args, " arguments");
}

group_column <- args[1]
input_file   <- args[2]
output_file  <- args[3]

#---------------------------------------------------------------------------------
# Reading input files

summary <- read_csv(input_file) |>
  group_by(!!!group_column) |>
  summarise(
    n = n()
  )

print(summary)

#---------------------------------------------------------------------------------
# Outputting dataset summary

message("[INFO] Writing summary to file: \"", output_file, "\"")

fwrite(as.data.table(summary), output_file)

message("[INFO] All done!")
