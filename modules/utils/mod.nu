# Gets the amount of threads to use by either using the environment variable DDC_THREADS
# or by defaulting to the amount of CPU cores.
export def get_threads [] {
  mut threads: int = sys cpu | length

  if $env.DDC_THREADS? != null {
    $threads = $env.DDC_THREADS | into int
  }

  return $threads
}

export def group_files_by_dataset [files: table] {
  mut results: record = {}

  for $file in $files {
    mut target = $results | get -i $file.dataset

    if $target == null {
      $target = {
        key: $file.dataset,
        years: [],
        files: []
      }

      $results = $results | insert $file.dataset $target
    }

    $target = $target
      | update "years" ($target.years | append $file.year)
      | update "files" ($target.files | append $file.output_path)

    $results = $results | update $file.dataset $target
  }

  return $results
}
