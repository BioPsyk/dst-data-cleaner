use ../utils

#=================================================================================
# Constants
#=================================================================================

const MODULE_DIR = path self .
const CATEGORIES = ["A", "B", "C", "D", "G", "H", "J", "L", "M", "N", "P", "R", "S", "V"]
const COLUMNS    = ["person_id", "atc_id", "ibnr_id", "dispensed_at", "volume", "volume_type_code", "pack_size", "strength", "strength_unit", "dosage_form", "source_file"]

#=================================================================================
# Commands
#=================================================================================

def split_lmdb_file [input_file: path, output_prefix: string] {
  let script_name = "split-lmdb-by-atc-category.sh"
  let script_path = $MODULE_DIR | path join "bin" $script_name

  run-external "bash" $script_path $input_file $output_prefix
}

#=================================================================================
# Exports
#=================================================================================

export def derive_dataset [lmdb_files: list<path>, output_prefix: string] {
  let threads = utils get_threads

  log info $"Creating prescriptions dataset from ($lmdb_files | length) LMDB files, using ($threads) threads"

  let dataset_files = $CATEGORIES
    | each {|cat| let fp = $"($output_prefix)-($cat).csv"; $COLUMNS | str join "," | save $fp; return $fp }

  $lmdb_files | par-each {|fp| split_lmdb_file $fp $output_prefix} --threads $threads

  let metadata_path = $"($output_prefix)_metadata.json"

  cp ($MODULE_DIR | path join "data" "prescriptions_metadata.json") $metadata_path

  return {
    datasets: $dataset_files,
    metadata: $metadata_path
  }
}
