# Dataset `prescriptions`

Contains one row for each prescription made in the Danish healthcare system that was dispensed. In this context, "dispensed" means that the patient went to the pharmacy to pick up a medicine that was prescribed to them. This dataset does not contain prescriptions that haven't been dispensed/picked up by the patient.

## Columns

|   index | name               | description                                        |
|---------|--------------------|----------------------------------------------------|
|       0 | `person_id`        | Unique (population wide) ID of the person          |
|       1 | `atc_id`           | WHO-defined Anatomical Therapeutical Chemical code |
|       2 | `ibnr_id`          | Identifier for the dispensing pharmacy             |
|       3 | `dispensed_at`     | Date when prescription was dispensed               |
|       4 | `volume`           | Number of defined daily doses per package          |
|       5 | `volume_type_code` | Unit used for a dose                               |
|       6 | `pack_size`        | Number of tablets/units per package                |
|       7 | `strength`         | Numerical strength per tablet/unit                 |
|       8 | `strength_unit`    | Unit used for strength                             |
|       9 | `dosage_form`      | Formulation of the drug                            |
|      10 | `source_file`      | File that row originates from                      |
  