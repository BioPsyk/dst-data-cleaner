use std/log

use ../utils

#=================================================================================
# Constants
#=================================================================================

const MODULE_DIR = path self .

#=================================================================================
# Commands
#=================================================================================

def sas7bdat_to_csv [file: record, output_dir: path] {
  let script_name = "sas7bdat-to-csv.R"
  let script_path = $MODULE_DIR | path join $script_name
  let input_path  = $file.dir | path join $"($file.base_name).sas7bdat"
  let columns     = ($file.columns | str join ",")
  let output_path = $output_dir | path join $"($file.base_name).csv"

  if $input_path == $output_path {
    error make { msg: $"Input/output points to the same file: ($input_path)" }
  }

  let result = run-external "Rscript" $script_path $input_path $columns $output_path | complete

  if $result.exit_code != 0 {
    error make { msg: $"Script ($script_name) failed to convert file ($input_path) into csv: ($result)" }
  }

  if not ($output_path | path exists) {
    error make { msg: $"Script ($script_name) did not create output file: ($output_path)" }
  }

  log info $"Converted ($file.base_name).sas7bdat to csv"

  $file
    | insert "input_path" $input_path
    | insert "output_path" $output_path
}

#=================================================================================
# Exports
#=================================================================================

export def main [metadata: record, grund_dir: path, external_dir: path, parent_output_dir: path] {
  let threads = utils get_threads
  let output_dir = $parent_output_dir | path join "stage1"

  let grund_files = ls $grund_dir
    | where type == file
    | get name
    | parse --regex "^(?P<dir>.+)/(?P<dataset>[A-Za-z_]+)(?P<year>[0-9]{4})(?P<month>[0-9]{2}).sas7bdat$"
    | insert "columns" {|row| $metadata.stage1 | get $row.dataset | get "columns"}
    | insert "base_name" {|row| [$row.dataset, $row.year, $row.month] | str join "" }

  let external_files = ls $external_dir
    | where type == file
    | get name
    | parse --regex "^(?P<dir>.+)/(?P<dataset>.+).sas7bdat$"
    | insert "columns" {|row| $metadata.stage1 | get $row.dataset | get "columns"}
    | insert "base_name" {|row| $row.dataset }
    | insert "year" 0
    | insert "month" 0

  let all_files = $grund_files ++ $external_files

  log info $"Stage 1: converting ($all_files | length) dataset files to csv, using ($threads) threads"

  mkdir $output_dir

  $all_files | par-each {|file| sas7bdat_to_csv $file $output_dir } --threads $threads
}
