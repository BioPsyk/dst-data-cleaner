#!/usr/bin/env nextflow

//---------------------------------------------------------------------------------
// Processes

//process concatYearlyFiles {
//  input:
//  tuple val(name), val(years), val(input_files)
//
//  output:
//  tuple val(name), path(output_file)
//
//  script:
//  output_file = "${name}.csv"
//  """
//  head -n 1 "${input_files[0]}" > "${output_file}"
//  awk -F "," 'FNR>1 { print \$0 }' ${input_files.join(" ")} >> "${output_file}"
//  """
//}

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

//---------------------------------------------------------------------------------

workflow stage2 {
  take:
  yearlyCsvFiles

  main:
  yearlyCsvFiles |
    groupTuple(by: 0) |
    set { groupedCsvFiles }

  groupedCsvFiles |
    filter{ it[0] == "bef" } |
    derivePopulationDataset |
    set { populationFiles }

  emit:
  populationFiles

  publish:
  populationFiles >> "stage2"
}
