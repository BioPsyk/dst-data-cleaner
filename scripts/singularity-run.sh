#!/usr/bin/env bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
project_dir=$(dirname "${script_dir}")

cd "${project_dir}"

source "${script_dir}/init-containerization.sh"

mount_flags=$(format_mount_flags "-B")

exec singularity run \
     --contain \
     --cleanenv \
     --cwd "/app" \
     ${mount_flags} \
     "tmp/${singularity_image_tag}" \
     "$@"
