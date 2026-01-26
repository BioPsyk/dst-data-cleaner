#!/usr/bin/env bash

set -euo pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
project_dir=$(dirname "${script_dir}")

cd "${project_dir}"

source "${script_dir}/init-containerization.sh"

echo ">> Building docker image"
./scripts/docker-build.sh

echo ">> Building singularity image"
./scripts/singularity-build.sh

echo ">> Packaging files"

packaging_dir="${project_dir}/tmp/packaging"

rm -rf "${packaging_dir}"

mkdir -p "${packaging_dir}/"{tmp}

cp bin "${packaging_dir}/" -R
cp modules "${packaging_dir}/" -R
cp workflows "${packaging_dir}/" -R
cp main.nu "${packaging_dir}/"
cp metadata.json "${packaging_dir}/"
cp ./scripts/singularity-run.sh "${packaging_dir}/scripts/"
cp ./scripts/init-containerization.sh "${packaging_dir}/scripts/"
cp ./docs "${packaging_dir}" -R
cp ./README.md "${packaging_dir}/"

target_path="${project_dir}/tmp/dst-data-cleaner_"$(cat "./VERSION")".tar.gz"

echo ">> Making zip archive"
cd "${packaging_dir}"
tar cvzf "${target_path}" .

echo "All done!"
