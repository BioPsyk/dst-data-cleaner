#!/usr/bin/env Rscript

suppressMessages(library(readr))
suppressMessages(library(dplyr))
suppressMessages(library(haven))

usage <- function() {
	message("csv-to-sas7bdat.R [INPUT_FILE] [OUTPUT_FILE]")
}

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
	usage()
	stop("Missing INPUT_FULE and OUTPUT_FILE arguments");
} else if (length(args) == 1) {
	usage()
	stop("Missing OUTPUT_FILE argument");
}

input_file  <- args[1]
output_file <- args[2]

input_dt <- read_csv(input_file)
write_sas(input_dt, output_file)
