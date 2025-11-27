#!/usr/bin/env nextflow

//---------------------------------------------------------------------------------
// Processes

process sas7bdatToCsv {
  input:
  tuple path(sas_file), val(name), val(year), val(columns)

  output:
  tuple path(csv_file), val(name), val(year)

  script:
  csv_file = "${name}-${year}.csv"
  """
  sas7bdat-to-csv.R \
    "${sas_file}"  \
    "${columns.join(",")}" \
    "${csv_file}"
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

  return [f, name, year, md["columns"]]
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

  yearlyCsvFiles |
    // We only need the file and the dataset name
    map(it -> it[0..1]) |
    // Group all the files by dataset name
    groupTuple(by: 1) |
    view

  emit:
  yearlyCsvFiles

  publish:
  yearlyCsvFiles >> "stage1/csv"
}
