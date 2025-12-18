#!/usr/bin/env nextflow

//---------------------------------------------------------------------------------
// Processes

process derivePopulationDataset {
  input:
  tuple val(input_name), val(input_years), val(input_files)

  output:
  tuple path("${output_prefix}.csv"), path("${output_prefix}_metadata.json")

  script:
  input_args    = input_years.withIndex().collect{ year, i -> "${year}:${input_files[i]}" }.join(" ")
  first_year    = Collections.min(input_years)
  last_year     = Collections.max(input_years)
  output_prefix = "population_${first_year}-${last_year}"
  """
  derive-population-dataset.R "${output_prefix}" ${input_args}
  """
}

process deriveDiagnosesDataset {
  input:
  file(metadata)

  output:
  tuple path("${output_prefix}.csv"), path("${output_prefix}_metadata.json")

  script:
  output_prefix = "diagnoses"
  """
  derive-diagnoses-dataset.R "${output_prefix}" "${metadata}"
  """
}

//---------------------------------------------------------------------------------
// Helpers

/**
 * This helper creates a map that contains all datasets needed to produce the diagnoses dataset.
 */
def createDiagnosesMetadata(datasets) {
  def lookup = [:]

  datasets.each{ it ->
    lookup[it[0]] =  [
      key: it[0],
      years: it[1],
      files: it[2].collect(f -> f.toString()) // Files needs to be strings, otherwise JSON encoding fails with StackOverflowError
    ]
  }

  def required = [
    "lpr_adm",
    "lpr_diag",
    "lpr_f_kontakter",
    "lpr_f_diagnoser",
    "patient_icd8",
    "patient_icd10",
    "diag_icd10",
    "psyk_adm",
    "psyk_diag"
  ]

  required.each{ k ->
    assert lookup.containsKey(k) : "Required dataset '${k}' was missing"
  }

  def result = [
    lpr2: [
      records: lookup["lpr_adm"],
      diagnoses: lookup["lpr_diag"]
    ],
    lpr3: [
      records: lookup["lpr_f_kontakter"],
      diagnoses: lookup["lpr_f_diagnoser"]
    ],
    pcrr1: [
      records: lookup["patient_icd8"],
      diagnoses: lookup["patient_icd8"] // The patient and diagnoses data is stored as a single file
    ],
    pcrr2: [
      records: lookup["patient_icd10"],
      diagnoses: lookup["diag_icd10"]
    ],
    pcrr3: [
      records: lookup["psyk_adm"],
      diagnoses: lookup["psyk_diag"]
    ]
  ]

  result.each{ k, v ->
    def records   = v["records"]
    def diagnoses = v["diagnoses"]

    def msg = """
Dataset group '${k}' had mismatching years between it's medical records and diagnoses:

- Medical records ('${records["key"]}') had the following years: ${records["years"].join(", ")}
- Diagnoses ('${diagnoses["key"]}') had the following years: ${diagnoses["years"].join(", ")}
    """

    assert records["years"].toSet() == diagnoses["years"].toSet() : msg
  }

  return result
}

//---------------------------------------------------------------------------------

workflow stage2 {
  take:
  yearlyCsvFiles
  externalCsvFiles

  main:
  yearlyCsvFiles |
    groupTuple(by: 0) | // Groups the files by dataset name
    set { groupedCsvFiles }

  groupedCsvFiles |
    filter{ it[0] == "bef" } |
    derivePopulationDataset |
    set { populationFiles }

  groupedCsvFiles |
    concat(
      externalCsvFiles.map(it -> [it[0], [0], [it[1]]] ) // Makes sure the tuple structure is the same
                                                        // as for yearly files for easier processing in 'createDiagnosesMetadata'
    ) |
    toList |
    map(it -> createDiagnosesMetadata(it)) |
    map(it -> groovy.json.JsonOutput.toJson(it)) |
    collectFile(name: "metadata.json", newLine: true) |
    deriveDiagnosesDataset |
    set { diagnosesFiles }

  emit:
  populationFiles
  diagnosesFiles

  publish:
  populationFiles >> "stage2"
  diagnosesFiles >> "stage2"
}
