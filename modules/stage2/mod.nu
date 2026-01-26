use ../utils
use ./diagnoses.nu
use ./population.nu
use ./prescriptions.nu

#=================================================================================
# Constants
#=================================================================================

const MODULE_DIR = path self .

#=================================================================================
# Commands
#=================================================================================

#=================================================================================
# Exports
#=================================================================================

export def main [stage1_results: table, parent_output_dir: path] {
  let threads = utils get_threads
  let output_dir = $parent_output_dir | path join "stage2"

  mkdir $output_dir

  log info $"Stage 2: Creating curated datasets"

  let bef_files  = $stage1_results | where dataset == "bef" | get "output_path" | sort
  let lmdb_files = $stage1_results | where dataset == "lmdb" | get "output_path" | sort

  return {
    diagnoses: (diagnoses derive_dataset $stage1_results ($output_dir | path join "diagnoses")),
    population: (population derive_dataset $bef_files ($output_dir | path join "population")),
    prescriptions: (prescriptions derive_dataset $lmdb_files ($output_dir | path join "prescriptions"))
  }
}
