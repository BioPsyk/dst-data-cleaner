#!/usr/bin/env nu

use std/log

use ./modules/stage1
use ./modules/stage2

def main [metadata_file: path, grund_dir: path, external_dir: path, output_dir: path] {
  let metadata   = open $metadata_file

  let stage1_results = stage1 $metadata $grund_dir $external_dir $output_dir
  let stage2_results = stage2 $stage1_results $output_dir

  log info "All done"

  return {
    stage1: ($stage1_results | get "output_path"),
    stage2: $stage2_results
  }
}
