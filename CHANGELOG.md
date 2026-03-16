# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.12.0]

### Changed

- NixOS 25.05 -> NixOS 25.11

## [0.11.0]

### Changed

- Removes all rows from curated datasets that contain empty/invalid primary key values:
  - `diagnoses`: `record_id` and `person_id` columns
  - `education`: `person_id` column
  - `education`: `person_id` column
  - `family_income`: `family_id` column
  - `income`: `person_id` column
  - `population`: `person_id` column

### Added

- Stage 1 datasets:
  - AKM
  - DODSAARS
  - DODSAASG
  - RAS
  - UDDA
- Stage 2 datasets:
  - Cause of death
  - Education
  - Family income
  - Income
  - Labour

### Fixed

- Error when datasets that is not in the metadata file is encountered
- Error when yearly datasets doesn't have a month in it's name
- Error when medical record with max/min year of NA
- Misinterpretation of ID columns that have very large numeric values
- Missing awk executable in singularity container

## [0.5.0]

### Added

- Stage 2 datasets:
  - Incomes
  - Family incomes

### Changed

- Pipeline is now implemented in nushell instead of nextflow

## [0.4.1]

### Added

- Stage 2 datasets:
  - Prescriptions

### Fixed

- Header of stage 2 dataset diagnoses contains an extra column that shouldn't be there

## [0.3.0]

### Changed

- Stage 2 datasets:
  - Are now named without start and end year
  - Have the first and last date found as period in their metadata file
    - Population uses the `born_at` column as date
    - Diagnoses uses the `starts_at` and `ends_at` column as the dates

## [0.2.1]

### Fixed

- Stage 2 diagnoses derivation
  - Incorrect column usage for diagnosis kind
  - Type conversion of joining `record_id` column

## [0.2.0]

### Added

- Stage 2:
  - Derivation of new diagnosis dataset

## [0.1.0]

### Added

- Stage 2:
  - Derivation of new population dataset

## [0.0.1]

### Added

- Initial project structure
