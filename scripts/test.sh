#!/usr/bin/env bash

set -euo pipefail

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
project_dir=$(dirname "${script_dir}")

cd "${project_dir}"

echo ">> Building docker image"
./scripts/docker-build.sh

echo ">> Building singularity image"
./scripts/singularity-build.sh

echo ">> Testing docker image"

data_dir="./test/data"
out_dir="./tmp/output"

rm -rf "${out_dir}"

mkdir -p "${out_dir}/"{stage1,stage2}

./scripts/docker-run.sh \
  ./main.nf \
  -resume \
  --data-dir="${data_dir}" \
  --output-dir "${out_dir}"

column -t -s "," ./tmp/output/stage2/population_198512-198612.csv

jq . ./tmp/output/stage2/population_198512-198612_metadata.json

echo ">> Testing singularity image"

rm -rf "${out_dir}"

mkdir -p "${out_dir}/"{stage1,stage2}

./scripts/singularity-run.sh \
  ./main.nf \
  -resume \
  --data-dir="${data_dir}" \
  --output-dir "${out_dir}"

column -t -s "," ./tmp/output/stage2/population_198512-198612.csv

jq . ./tmp/output/stage2/population_198512-198612_metadata.json

echo ">> Testing NixOS"

rm -rf "${out_dir}"

mkdir -p "${out_dir}/"{stage1,stage2}

./scripts/singularity-run.sh \
  ./main.nf \
  -resume \
  --data-dir="${data_dir}" \
  --output-dir "${out_dir}"

column -t -s "," ./tmp/output/stage2/population_198512-198612.csv

jq . ./tmp/output/stage2/population_198512-198612_metadata.json
