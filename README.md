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

![Domain model 1](file:./docs/images/domain-model1.png)

The statistical data that `dst` provides are made up of around [**400** distinct datasets](https://danmarksdatavindue.dk/DDVDatasafari/#/registers).
Each dataset has a unique name and is provided as a set of "dataset files" in the proprietary
format `.sas7bdat`. Each dataset file represents a single year and holds the data produced in that year
(expect for small datasets, they only have one file with all data).

Here's where the pipeline `dst-data-cleaner` comes in the picture.

![Domain model 2](file:./docs/images/domain-model2.png)

## Project overview 👀

TBD

## Quick Start 🚀


TBD

## Support 💬

If you have any questions, suggestions, or need assistance, please open a GitHub issue.
