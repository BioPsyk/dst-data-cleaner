#!/usr/bin/env bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
project_dir=$(dirname "${script_dir}")

function format_mount_flags() {
  flag="${1}"

  for mount in "${mounts[@]}"
  do
    echo "${flag} ${project_dir}/${mount}:/app/${mount} "
  done
}

cd "${project_dir}"

mounts=(
  ".nextflow"
  "bin"
  "lib"
  "main.nf"
  "metadata.json"
  "test"
  "tmp"
  "work"
  "workflows"
)

docker_image_tag="dst-data-cleaner:"$(cat "./VERSION")
singularity_image_tag="dst-data-cleaner_"$(cat "./VERSION")".sif"

mkdir -p tmp
