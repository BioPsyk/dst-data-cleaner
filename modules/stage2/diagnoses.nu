use ../utils

#=================================================================================
# Constants
#=================================================================================

const MODULE_DIR = path self .

#=================================================================================
# Commands
#=================================================================================

def create_datasets_file [stage1_results: table, output_prefix: string] {
  let datasets = utils group_files_by_dataset $stage1_results

  let results = {
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

  let results_path = $"($output_prefix)_datasets.json"

  $results | save $results_path

  return $results_path
}

#=================================================================================
# Exports
#=================================================================================

export def derive_dataset [stage1_results: table, output_prefix: string] {
  let datasets_path = create_datasets_file $stage1_results $output_prefix
  let script_name   = "derive-diagnoses-dataset.R"
  let script_path   = $MODULE_DIR | path join "bin" $script_name
  let dataset_path  = $"($output_prefix).csv"
  let metadata_path = $"($output_prefix)_metadata.json"

  let result = run-external "Rscript" $script_path $output_prefix $datasets_path | complete

  if $result.exit_code != 0 {
    error make { msg: $"Script '($script_name)' failed: ($result)" }
  }

  if not ($dataset_path | path exists) {
    error make { msg: $"Script '($script_name)' did not create output dataset file: ($dataset_path)" }
  }

  if not ($metadata_path | path exists) {
    error make { msg: $"Script '($script_name)' did not create output metadata file: ($metadata_path)" }
  }

  log info $"Created diagnoses dataset"

  return {
    dataset: $dataset_path,
    metadata: $metadata_path
  }
}
