use ../utils

use ./deaths.nu
use ./diagnoses.nu
use ./education.nu
use ./employment.nu
use ./family_income.nu
use ./income.nu
use ./population.nu
use ./prescriptions.nu

#=================================================================================
# Constants
#=================================================================================

const MODULE_DIR = path self .

#=================================================================================
# Exports
#=================================================================================

export def main [stage1_results: table, parent_output_dir: path] {
  let threads = utils get_threads
  let output_dir = $parent_output_dir | path join "stage2"

  mkdir $output_dir

  log info $"Stage 2: Creating curated datasets"

  let bef_files    = $stage1_results | where dataset == "bef" | get "output_path" | sort
  let dodsaa_files = $stage1_results | where {|el| $el.dataset | str starts-with "dodsaa" } | get "output_path" | sort
  let faik_files   = $stage1_results | where dataset == "faik" | get "output_path" | sort
  let ind_files    = $stage1_results | where dataset == "ind" | get "output_path" | sort
  let lmdb_files   = $stage1_results | where dataset == "lmdb" | get "output_path" | sort
  let ras_files    = $stage1_results | where dataset == "ras" | get "output_path" | sort
  let udda_files   = $stage1_results | where dataset == "udda" | get "output_path" | sort

  return {
    deaths: (deaths derive_dataset $dodsaa_files ($output_dir | path join "deaths")),
    diagnoses: (diagnoses derive_dataset $stage1_results ($output_dir | path join "diagnoses")),
    education: (education derive_dataset $udda_files ($output_dir | path join "education")),
    employment: (employment derive_dataset $ras_files ($output_dir | path join "employment")),
    family_income: (family_income derive_dataset $faik_files ($output_dir | path join "family_income")),
    income: (income derive_dataset $ind_files ($output_dir | path join "income")),
    population: (population derive_dataset $bef_files ($output_dir | path join "population")),
    prescriptions: (prescriptions derive_dataset $lmdb_files ($output_dir | path join "prescriptions"))
  }
}
