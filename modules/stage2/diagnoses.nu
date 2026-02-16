use ../utils

#=================================================================================
# Constants
#=================================================================================

const MODULE_DIR = path self .

#=================================================================================
# Commands
#=================================================================================

def collect_datasets [stage1_results: table] {
  let datasets = utils group_files_by_dataset $stage1_results

  return {
    lpr2: {
      records: $datasets.lpr_adm,
      diagnoses: $datasets.lpr_diag
    },
    lpr3: {
      records: $datasets.lpr_f_kontakter,
      diagnoses: $datasets.lpr_f_diagnoser
    },
    pcrr1: {
      records: $datasets.patient_icd8,
      diagnoses: $datasets.patient_icd8 # The patient and diagnoses data is stored as a single file
    },
    pcrr2: {
      records: $datasets.patient_icd10,
      diagnoses: $datasets.diag_icd10
    },
    pcrr3: {
      records: $datasets.psyk_adm,
      diagnoses: $datasets.psyk_diag
    }
  }
}

#=================================================================================
# Exports
#=================================================================================

export def derive_dataset [stage1_results: table, output_prefix: string] {
  let datasets      = collect_datasets $stage1_results
  let datasets_path = $"($output_prefix)_datasets.json"
  let script_name   = "derive-diagnoses-dataset.R"
  let script_path   = $MODULE_DIR | path join "bin" $script_name
  let dataset_path  = $"($output_prefix).csv"
  let metadata_path = $"($output_prefix)_metadata.json"

  log info $"Creating diagnoses dataset from datasets ($datasets | columns | str join ', ')"

  $datasets | save $datasets_path

  run-external "Rscript" $script_path $output_prefix $datasets_path

  if $env.LAST_EXIT_CODE != 0 {
    error make { msg: $"Script '($script_name)' failed" }
  }

  rm --permanent $datasets_path

  if not ($dataset_path | path exists) {
    error make { msg: $"Script '($script_name)' did not create output dataset file: ($dataset_path)" }
  }

  if not ($metadata_path | path exists) {
    error make { msg: $"Script '($script_name)' did not create output metadata file: ($metadata_path)" }
  }

  return {
    dataset: $dataset_path,
    metadata: $metadata_path
  }
}
