#!/usr/bin/env bash

set -euo pipefail

INPUT_PATH="${1}"
OUTPUT_PREFIX="${2}"

if [[ ! -f "${INPUT_PATH}" ]]; then
  echo "Argument 1 file path '${INPUT_PATH}' was not found";
  exit 1
fi

>&2 echo "Failed to process given input '${INPUT_PATH}'"
exit 1

tail -n+2 "${INPUT_PATH}" | awk -F , '{ print >> "'${OUTPUT_PREFIX}'-"substr($2, 0, 1)".csv" }'
