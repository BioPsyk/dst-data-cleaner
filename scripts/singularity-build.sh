#!/usr/bin/env bash

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${script_dir}/init-containerization.sh"

if [[ ! -f "tmp/${singularity_image_tag}" ]];
then
  exec singularity build "tmp/${singularity_image_tag}" \
       docker-daemon:"${docker_image_tag}"
else
  echo "[INFO] Singularity image already exists, ignoring"
fi
