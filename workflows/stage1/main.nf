#!/usr/bin/env nextflow

//---------------------------------------------------------------------------------
// Processes

process sas7bdatToCsv {
  input:
  tuple path(sas_file), val(metadata)

  output:
  tuple path(csv_file), val(metadata)

  script:
  csv_file = "${metadata["key"]}-${metadata["date"]}.csv"
  """
  sas7bdat-to-csv.R \
    "${sas_file}"  \
    "${metadata["columns"].join(",")}" \
    "${csv_file}"
  """
}

//---------------------------------------------------------------------------------
// Helpers

def attachMetadata(metadata, f) {
  def matcher = f.getBaseName() =~ /^(?<key>[A-Za-z]+)(?<date>[0-9]+)$/;

  if (!matcher.matches()) {
    throw new Exception(
      "Failed to attach metadata to file '${f.getName()}', which did not match the expected" +
        "filename pattern '/^[A-Za-z]+[0-9]+\$/'"
    );
  }

  def key  = matcher.group("key")
  def date = matcher.group("date")
  def md   = metadata[key]

  if (!md) md = metadata[key.toUpperCase()]
  if (!md) return null

  md["key"]  = key
  md["date"] = date

  return [f, md]
}

//---------------------------------------------------------------------------------

workflow stage1 {
  take:
  metadata
  sasFiles

  main:
  sasFiles |
    map(f -> attachMetadata(metadata, f)) |
    sas7bdatToCsv |
    set{ csvFiles }

  emit:
  csvFiles

  publish:
  csvFiles >> "stage1/csv"
}
