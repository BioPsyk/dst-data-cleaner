# Dataset `employment`

Contains yearly employment status of every person in the populuation. Contains years 1985 to 2020

## Columns

|   index | name              | description                                                                                                                                                                                       |
|---------|-------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|       0 | `person_id`       | Unique (population wide) ID of the person                                                                                                                                                         |
|       1 | `year`            | The year that the employment status is for.                                                                                                                                                       |
|       2 | `status_source`   | In the original dataset 4 different columns were used to represent the employment status. This column contains the name of original column that the status was extracted from.                    |
|       3 | `status`          | A code that represents the employment status of the person for the current year.                                                                                                                  |
|       4 | `industry_source` | In the original dataset 3 different columns were used to represent the industry of the persons employment. This column contains the name of original column that the industry was extracted from. |
|       5 | `industry`        | A code that represents which industry the person was working in for the current year.                                                                                                             |
|       6 | `source_file`     | Name of the dataset file that this row originates from.                                                                                                                                           |
  