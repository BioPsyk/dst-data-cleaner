#!/usr/bin/env nextflow

//---------------------------------------------------------------------------------
// Processes

process sas7bdatToCsv {
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

//---------------------------------------------------------------------------------
// Helpers

def attachMetadata(metadata, f) {
  def matcher = f.getBaseName() =~ /^(?<name>[A-Za-z]+)(?<year>[0-9]+)$/;

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

//---------------------------------------------------------------------------------

workflow stage1 {
  take:
  metadata
  yearlySasFiles

  main:
  yearlySasFiles |
    map(it -> attachMetadata(metadata, it)) |
    sas7bdatToCsv |
    set{ yearlyCsvFiles }

  emit:
  yearlyCsvFiles

  publish:
  yearlyCsvFiles >> "stage1"
}
