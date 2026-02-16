use ../utils

#=================================================================================
# Constants
#=================================================================================

const MODULE_DIR = path self .

const DODSAARS_COLS = ["PNR", "D_DODSDTO", "C_DODSMAADE", "C_DOD1", "C_DOD2", "C_DOD3", "C_DOD4"]
const DODSAASG_COLS = ["PNR", "D_DODSDATO", "C_DODSMAADE", "C_DOD_1A", "C_DOD_1B", "C_DOD_1C", "C_DOD_1D"]

const OUTPUT_COLS = ["person_id", "deceased_at", "mode", "cause_1_icd_id", "cause_2_icd_id", "cause_3_icd_id", "cause_4_icd_id", "source_file"]

#=================================================================================
# Commands
#=================================================================================

def process_file [input_path: path, output_path: path] {
  let file_name  = $input_path | path basename
  mut input_cols = []

  if ($file_name | str downcase | str starts-with "dodsaars") {
    $input_cols = $DODSAARS_COLS
  } else {
    $input_cols = $DODSAASG_COLS
  }

  open $input_path
    | select ...$input_cols
    | insert source_file $file_name
    | rename ...$OUTPUT_COLS
    | to csv -n
    | save $output_path --append
}

#=================================================================================
# Exports
#=================================================================================

export def derive_dataset [dodsaa_files: list<path>, output_prefix: string] {
  let threads       = utils get_threads
  let dataset_path  = $"($output_prefix).csv"
  let metadata_path = $"($output_prefix)_metadata.json"

  log info $"Creating deaths dataset from ($dodsaa_files | length) dodsaa* files, using ($threads) threads"

  cp ($MODULE_DIR | path join "data" "deaths_metadata.json") $metadata_path

  ($OUTPUT_COLS | str join ",") ++ "\n" | save $dataset_path

  $dodsaa_files | par-each {|fp| process_file $fp $dataset_path } --threads $threads

  {
    dataset: $dataset_path,
    metadata: $metadata_path
  }
}
