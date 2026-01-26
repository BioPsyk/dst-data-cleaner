const MODULE_DIR = path self .

export def derive_dataset [bef_files: list<path>, output_prefix: string] {
  let script_name   = "derive-population-dataset.R"
  let script_path   = $MODULE_DIR | path join "bin" $script_name
  let dataset_path  = $"($output_prefix).csv"
  let metadata_path = $"($output_prefix)_metadata.json"

  let result = run-external "Rscript" $script_path $output_prefix ...$bef_files | complete

  if $result.exit_code != 0 {
    error make { msg: $"Script ($script_name) failed to created population dataset from BEF files: ($result)" }
  }

  if not ($dataset_path | path exists) {
    error make { msg: $"Script ($script_name) did not create output dataset file: ($dataset_path)" }
  }

  if not ($metadata_path | path exists) {
    error make { msg: $"Script ($script_name) did not create output metadata file: ($metadata_path)" }
  }

  log info $"Created population dataset from ($bef_files | length) BEF files"

  return {
    dataset: $dataset_path,
    metadata: $metadata_path
  }
}
