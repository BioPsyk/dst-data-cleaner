#!/usr/bin/env nextflow

//---------------------------------------------------------------------------------
// Processes

process yearlySas7bdatToCsv {
  input:
  tuple val(name), val(year), path(input_file), val(columns)

  output:
  tuple val(name), val(year), path(output_file)

  script:
  output_file = "${name}-${year}.csv"
  """
  sas7bdat-to-csv.R \
    "${input_file}"  \
    "${columns.join(",")}" \
    "${output_file}"
  """
}

process externalSas7bdatToCsv {
  input:
  tuple val(name), path(input_file), val(columns)

  output:
  tuple val(name), path(output_file)

  script:
  output_file = "${name}.csv"
  """
  sas7bdat-to-csv.R \
    "${input_file}"  \
    "${columns.join(",")}" \
    "${output_file}"
  """
}

//---------------------------------------------------------------------------------
// Helpers

def attachYearlyMetadata(metadata, f) {
  def matcher = f.getBaseName() =~ /^(?<name>[A-Za-z_]+)(?<year>[0-9]+)$/;

  if (!matcher.matches()) {
    throw new Exception(
      "Failed to attach metadata to file '${f.getName()}', which did not match the expected" +
        "filename pattern '/^[A-Za-z]+[0-9]+\$/'"
    );
  }

  def name = matcher.group("name")
  def year = matcher.group("year")
  def md   = metadata[name]

  if (!md) md = metadata[name.toUpperCase()]
  if (!md) return null

  return [name, year, f, md["columns"]]
}

def attachExternalMetadata(metadata, f) {
  def name = f.getBaseName()
  def md   = metadata[name]

  // Try again, but with all lower case
  if (!md) md = metadata[name.toLowerCase()]
  if (!md) return null

  return [name, f, md["columns"]]
}

//---------------------------------------------------------------------------------

workflow stage1 {
  take:
  metadata
  yearlySasFiles
  externalSasFiles

  main:
  yearlySasFiles |
    map(it -> attachYearlyMetadata(metadata, it)) |
    yearlySas7bdatToCsv |
    set{ yearlyCsvFiles }

  externalSasFiles |
    map(it -> attachExternalMetadata(metadata, it)) |
    externalSas7bdatToCsv |
    set{ externalCsvFiles }

  emit:
  yearlyCsvFiles
  externalCsvFiles

  publish:
  yearlyCsvFiles >> "stage1/grund"
  externalCsvFiles >> "stage1/external"
}
