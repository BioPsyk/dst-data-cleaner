#!/usr/bin/env bash

set -euo pipefail

declare -a categories=("A" "B" "C" "D" "G" "H" "J" "L" "M" "N" "P" "R" "S" "V")

for cat in "${categories[@]}"; do
  echo "person_id,atc_id,ibnr_id,dispensed_at,volume,volume_type_code,pack_size,strength,strength_unit,dosage_form,source_file" >> "dispensed_prescriptions-${cat}.csv"
done

for f in "$@"; do
  echo "[INFO] Processing file: '${f}'"
  tail -n+2 "${f}" | awk -F , '{ print >> "dispensed_prescriptions-"substr($2, 0, 1)".csv" }'
done

cat <<EOF > "dispensed_prescriptions_metadata.json"
{
  "key": "dispensed_prescriptions",
  "title": "Dispensed prescriptions",
  "description": "This dataset contains one row for each prescription made in the Danish healthcare system that was dispensed. In this context, "dispensed" means that the patient went to the pharmacy to pick up a medicine that was prescribed to them. This dataset does not contain prescriptions that haven't been dispensed/picked up by the patient.",
  "file_format": {
    "extension": "csv",
    "type": "text",
    "delimiter": ",",
    "quote": "\"",
    "linebreaks": "\n"
  },
  "size": 0,
  "sorted_by": [],
  "columns": {
    "person_id": {
      "index": 0,
      "title": "Civil Personal Register (CPR) number",
      "description": "Unique (population wide) ID of the person",
      "examples": [
        "",
        "846315",
        "0077131291838"
      ],
      "type": "string",
      "nullable": false,
      "relations": [
        {
          "kind": "originates_from",
          "target": "urn:column:dst:LMDB:PNR"
        }
      ]
    },
    "atc_id": {
      "index": 1,
      "title": "WHO-defined Anatomical Therapeutical Chemical code",
      "description": "",
      "type": "code",
      "nullable": true,
      "relations": [
        {
          "kind": "code",
          "target": "urn:code:sds:SKS"
        },
        {
          "kind": "originates_from",
          "target": "urn:column:dst:LMDB:ATC"
        }
      ]
    },
    "ibnr_id": {
      "index": 2,
      "title": "Identifier for the dispensing pharmacy",
      "description": "",
      "type": "string",
      "nullable": false,
      "relations": [
        {
          "kind": "originates_from",
          "target": "urn:column:dst:LMDB:IBNR"
        }
      ]
    },
    "dispensed_at": {
      "index": 3,
      "title": "Date when prescription was dispensed",
      "description": "",
      "type": "string",
      "nullable": false,
      "relations": [
        {
          "kind": "originates_from",
          "target": "urn:column:dst:LMDB:EKSD"
        }
      ]
    },
    "volume": {
      "index": 4,
      "title": "Number of defined daily doses per package",
      "description": "",
      "type": "number",
      "nullable": false,
      "relations": [
        {
          "kind": "originates_from",
          "target": "urn:column:dst:LMDB:VOLUME"
        }
      ]
    },
    "volume_type_code": {
      "index": 5,
      "title": "Unit used for a dose",
      "description": "",
      "type": "string",
      "nullable": false,
      "relations": [
        {
          "kind": "originates_from",
          "target": "urn:column:dst:LMDB:VOLTYPECODE"
        }
      ]
    },
    "pack_size": {
      "index": 6,
      "title": "Number of tablets/units per package",
      "description": "",
      "type": "string",
      "nullable": false,
      "relations": [
        {
          "kind": "originates_from",
          "target": "urn:column:dst:LMDB:PACKSIZE"
        }
      ]
    },
    "strength": {
      "index": 7,
      "title": "Numerical strength per tablet/unit",
      "description": "",
      "type": "number",
      "nullable": false,
      "relations": [
        {
          "kind": "originates_from",
          "target": "urn:column:dst:LMDB:STRNUM"
        }
      ]
    },
    "strength_unit": {
      "index": 8,
      "title": "Unit used for strength",
      "description": "",
      "type": "string",
      "nullable": false,
      "relations": [
        {
          "kind": "originates_from",
          "target": "urn:column:dst:LMDB:STRUNIT"
        }
      ]
    },
    "dosage_form": {
      "index": 9,
      "title": "Formulation of the drug",
      "description": "",
      "type": "string",
      "nullable": false,
      "relations": [
        {
          "kind": "originates_from",
          "target": "urn:column:dst:LMDB:DOSFORM"
        }
      ]
    },
    "source_file": {
      "index": 10,
      "title": "File that row originates from",
      "description": "",
      "type": "string",
      "nullable": false
    }
  }
}
EOF
