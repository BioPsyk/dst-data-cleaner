<br>

<div align="center">

  ![Logotype](./docs/images/dst-data-cleaner-logotype.png)

  <p align="center">
    <strong>Dst-data-cleaner is a <a href="https://www.nextflow.io/">Nextflow</a> pipeline that cleans datasets provided by <a href="https://www.dst.dk/en/">Statistics Denmark</a></strong>
  </p>

</div>

The goal of this pipeline is facilitate register based research by producing data that is:

- Easy to work with
- Prepared for downstream pipeline usage
- Not tied to proprietary tooling

## How it works ⚙️

In Denmark there are around **40** nation registers that keep track of various aspects of Danish society. These
registers provides "register data" for different governmental organizations, where `dst` is one of those
organizations. In turn `dst` provides "statistical data" for research organizations, that is has compiled
from the register data it received from the national registers.

The statistical data that `dst` provides are made up of around
[**400** distinct datasets](https://danmarksdatavindue.dk/DDVDatasafari/#/registers).
Each dataset has a unique name and is provided as a set of "dataset files" in the proprietary
format `.sas7bdat`. Each dataset file represents a single year and holds the data produced in that year
(expect for small datasets, they only have one file with all data).

Here's where the pipeline `dst-data-cleaner` comes into the picture. It processes the data in 2 stages:

- **Stage 1**:
    - Convert `.sas7bdat` files into `.csv` files
    - Exclude irrelevant columns
- **Stage 2**:
    - Create new opinionated datasets by manipulating and combining related datasets

![Pipeline domain model](./docs/images/domain-model-pipeline.png)

**Stage1** of the pipeline is only about picking out what data to clean and changing the storage
format of the data. The actual data is not manipulated in any way.

**Stage2** of the pipeline is where decisions are taken that can affect research results. The data is
manipulated and related datasets are merged together to form new datasets.

By keeping the files produced in both stages, researchers can either use the opinionated datasets
that are easier to work with, or if they are doing their own custom cleaning, they can use the unchanged
datasets.

## New datasets

These are the new datasets that are derived in stage 2 of the pipeline:

### Population

Population contains one row for each unique individual in the population. Each row has the following columns:

| Index | Name          | Description                                             |
|-------|---------------|---------------------------------------------------------|
| 0     | person_id     | Unique (population wide) ID of the person               |
| 1     | gender        | Gender of the person                                    |
| 2     | born_at       | Birthdate of person, in the format YYYY-MM-DD.          |
| 3     | birthplace_id | ID of the location where the person was born.           |
| 4     | mother_id     | ID of the persons mother (legal, not biological).       |
| 5     | father_id     | ID of the persons father (legal, not biological).       |
| 6     | family_id     | ID of the family that the person belongs to.            |
| 7     | source_file   | Name of the dataset file that this row originates from. |

### Diagnoses

Population contains one row for each distinct diagnosis made in the Danish healthcare system. Each row has the following columns:

| Index | Name                  | Description                                                                                                                     |
|-------|-----------------------|---------------------------------------------------------------------------------------------------------------------------------|
| 0     | person_id             | Unique (population wide) ID of the person that was diagnosed                                                                    |
| 1     | record_id             | Unique (register wide) ID of the medical record which the diagnosis belongs to                                                  |
| 2     | patient_kind          | Code for the kind of patient the medical record was created as. Note that different codes were used by the different registers. |
| 3     | starts_at             | Starting date of medical record                                                                                                 |
| 4     | ends_at               | Ending date of medical record                                                                                                   |
| 5     | diagnosis_id          | SKS-code (D-code) or ICD-8 code for the diagnosis                                                                               |
| 6     | diagnosis_kind        | Code for the kind of diagnosis made. Note that different codes were used by the different registers.                            |
| 7     | record_source_file    | Name of the dataset file that the medical record data of this row originates from.                                              |
| 8     | diagnosis_source_file | Name of the dataset file that the diagnosis data of this row originates from.                                                   |

## Support 💬

If you have any questions, suggestions, or need assistance, please [open a GitHub Issue](https://github.com/BioPsyk/dst-data-cleaner/issues/new).
