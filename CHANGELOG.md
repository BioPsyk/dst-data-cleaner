# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.1]

## Added

- Stage 2 datasets:
  - Prescriptions

## Fixed

- Header of stage 2 dataset diagnoses contains an extra column that shouldn't be there

## [0.3.0]

## Changed

- Stage 2 datasets:
  - Are now named without start and end year
  - Have the first and last date found as period in their metadata file
    - Population uses the `born_at` column as date
    - Diagnoses uses the `starts_at` and `ends_at` column as the dates

## [0.2.1]

## Fixed

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
