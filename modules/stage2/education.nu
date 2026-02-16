const MODULE_DIR = path self .

export def derive_dataset [udda_files: list<path>, output_prefix: string] {
  let script_name   = "derive-education-dataset.R"
  let script_path   = $MODULE_DIR | path join "bin" $script_name
  let dataset_path  = $"($output_prefix).csv"
  let metadata_path = $"($output_prefix)_metadata.json"

  log info $"Creating education dataset from ($udda_files | length) UDDA files"

  run-external "Rscript" $script_path $output_prefix ...$udda_files

  if $env.LAST_EXIT_CODE != 0 {
    error make { msg: $"Script ($script_name) failed to created education dataset from UDDA files" }
  }

  if not ($dataset_path | path exists) {
    error make { msg: $"Script ($script_name) did not create output dataset file: ($dataset_path)" }
  }

  if not ($metadata_path | path exists) {
    error make { msg: $"Script ($script_name) did not create output metadata file: ($metadata_path)" }
  }

  return {
    dataset: $dataset_path,
    metadata: $metadata_path
  }
}
