use ../utils

#=================================================================================
# Constants
#=================================================================================

const MODULE_DIR = path self .

#=================================================================================
# Commands
#=================================================================================

def split_lmdb_file [input_file: string, output_prefix: string] {
  let script_name = "split-lmdb-by-atc-category.sh"
  let script_path = $MODULE_DIR | path join "bin" $script_name

  let result = run-external "bash" $script_path $input_file $output_prefix | complete

  if $result.exit_code != 0 {
    error make { msg: $"Script ($script_name) failed to split LMDB file ($input_file): ($result)" }
  }

  $result
}

#=================================================================================
# Exports
#=================================================================================

export def derive_dataset [lmdb_files: list<path>, output_prefix: string] {
  const categories = ["A", "B", "C", "D", "G", "H", "J", "L", "M", "N", "P", "R", "S", "V"]
  const columns    = ["person_id", "atc_id", "ibnr_id", "dispensed_at", "volume", "volume_type_code", "pack_size", "strength", "strength_unit", "dosage_form", "source_file"]

  let threads = utils get_threads

  let dataset_files = $categories
    | par-each {|cat| let fp = $"($output_prefix)-($cat).csv"; $columns | str join "," | save $fp; return $fp } --threads $threads

  let results = $lmdb_files | par-each {|fp| split_lmdb_file $fp $output_prefix} --threads $threads
  let metadata_output_path = $"($output_prefix)_metadata.json"

  log info $"Created prescriptions dataset from ($lmdb_files | length) LMDB files"

  cp ($MODULE_DIR | path join "data" "prescriptions_metadata.json") $metadata_output_path

  return {
    datasets: $dataset_files,
    metadata: $metadata_output_path
  }
}
