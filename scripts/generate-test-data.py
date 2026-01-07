#!/usr/bin/env python3

import os
import logging
import argparse
import datetime
import csv
import json
from subprocess import check_call
from collections import OrderedDict

from faker import Faker

#-------------------------------------------------------------------------------
# Constants

SCRIPT_NAME = "generate-test-data"
DATE_FORMAT = "%Y%m%d"
PROJECT_DIR = os.path.realpath(os.path.dirname(os.path.dirname(__file__)))

#-------------------------------------------------------------------------------
# Logger setup

logger = logging.getLogger(SCRIPT_NAME)
logger.setLevel(logging.DEBUG)

basic_formatter = logging.Formatter(
  "[%(levelname)s] %(message)s"
)

stream_handler = logging.StreamHandler()
stream_handler.setLevel(logging.INFO)

stream_handler.setFormatter(basic_formatter)
logger.addHandler(stream_handler)

#-------------------------------------------------------------------------------
# BEF

def fake_bef_person(fake, gender, family, residency, mother=None, father=None):
  if mother is None and father is None:
    born_at = fake.past_date(start_date='-40y').strftime(DATE_FORMAT)
  else:
    born_at = fake.past_date(start_date='-20y').strftime(DATE_FORMAT)

  return {
    "PNR": fake.random_int(max=9999999),
    "KOEN": gender,
    "FOED_DAG": born_at,
    "FOEDREG_KODE": fake.random_int(min=1, max=9999),
    "MOR_ID": "" if mother is None else mother["PNR"],
    "FAR_ID": "" if father is None else father["PNR"],
    "FAMILIE_ID": family["id"],
    "ADRESSE_ID": residency["id"],
    "BOPIKOM": residency["municipality_id"],
    "BOP_VFRA": residency["starts_at"],
  }

def fake_bef_family(fake):
  family = {
    "id": fake.random_int(max=9999999)
  }

  residency = {
    "id": fake.random_int(max=9999999),
    "municipality_id": fake.random_int(max=9999999),
    "starts_at": fake.past_date(start_date='-10y').strftime(DATE_FORMAT)
  }

  mother = fake_bef_person(fake, 2, family, residency)
  father = fake_bef_person(fake, 1, family, residency)
  child  = fake_bef_person(fake, fake.random_int(min=1, max=2), family, residency, mother, father)

  return [mother, father, child]

def fake_bef_dataset(fake, rows_count):
  result = []

  for _ in range(rows_count):
    result += fake_bef_family(fake)

  return result

#-------------------------------------------------------------------------------
# LMDB

def fake_lmdb_prescription(fake, bef_person):
  birth_date = datetime.datetime.strptime(bef_person["FOED_DAG"], DATE_FORMAT)

  return {
    "PNR": bef_person["PNR"],
    "ATC": fake.bothify(text="?##??##", letters='ABCDGHJLMNPQRSV'),
    "IBNR": fake.random_int(max=9999999),
    "EKSD": fake.past_date(start_date=birth_date),
    "VOLUME": fake.random_int(min=1, max=1000),
    "VOLTYPECODE": fake.random_element(elements=("ST", "DW", "ML")),
    "PACKSIZE": fake.random_int(min=1, max=200),
    "STRNUM": fake.random_int(min=1, max=999999),
    "STRUNIT": fake.random_element(elements=("PC", "BHS", "MGM", "SQM")),
    "DOSFORM": fake.random_element(elements=("INJVSKS", "PULORES", "SOLVPA"))
  }

def fake_lmdb_dataset(fake, bef_dataset):
  result = []

  for row in bef_dataset:
    prescriptions_count = fake.random_int(min=1, max=5)

    for _ in range(0, prescriptions_count):
      result.append(
        fake_lmdb_prescription(fake, row)
      )

  return result

#-------------------------------------------------------------------------------
# PCR icd8 dataset

def fake_pcr_patient_icd8_record(fake, bef_person):
  birth_date = datetime.datetime.strptime(bef_person["FOED_DAG"], DATE_FORMAT)
  start_date = fake.past_date(start_date=birth_date)
  end_date   = fake.past_date(start_date=start_date)

  return {
    "PAT_SEQ": fake.random_int(max=9999999),
    "CPRNR": bef_person["PNR"],
    "PTTYPE": fake.random_element(elements=[0, 1, 2, 4, 5]),
    "INDLDATO": start_date,
    "UDSKDATO": end_date,
    "HOVEDDIAG": fake.random_element(elements=["00999", "11609", "42009"]),
    "MODIFHD": fake.random_int(max=9)
  }

def fake_pcr_patient_icd8_dataset(fake, bef_datasets):
  result = []

  for row in bef_datasets:
    records_count = fake.random_int(min=1, max=5)

    for _ in range(0, records_count):
      result.append(
        fake_pcr_patient_icd8_record(fake, row)
      )

  return result

#-------------------------------------------------------------------------------
# PCR icd10 datasets

def fake_pcr_diag_icd10(fake, pcr_record):
  return {
    "PAT_SEQ": pcr_record["PAT_SEQ"],
    "DIAG": fake.random_element(elements=["DF20", "DF30", "DF25"]),
    "DART": fake.random_element(elements=["0", "A", "B", "G", "H"])
  }

def fake_pcr_diag_icd10_dataset(fake, pcr_records):
  result = []

  for record in pcr_records:
    diagnoses_count = fake.random_int(min=0, max=2)

    for _ in range(0, diagnoses_count):
      result.append(
        fake_pcr_diag_icd10(fake, record)
      )

  return result

def fake_pcr_patient_icd10_record(fake, bef_person):
  birth_date = datetime.datetime.strptime(bef_person["FOED_DAG"], DATE_FORMAT)
  start_date = fake.past_date(start_date=birth_date)
  end_date   = fake.past_date(start_date=start_date)

  return {
    "PAT_SEQ": fake.random_int(max=9999999),
    "CPRNR": bef_person["PNR"],
    "PTTYPE": fake.random_element(elements=[0, 1, 2, 4, 5]),
    "INDLDATO": start_date,
    "UDSKDATO": end_date
  }

def fake_pcr_patient_icd10_dataset(fake, bef_dataset):
  result = []

  for row in bef_dataset:
    records_count = fake.random_int(min=1, max=5)

    for _ in range(0, records_count):
      result.append(
        fake_pcr_patient_icd10_record(fake, row)
      )

  return result

#-------------------------------------------------------------------------------
# LPR2 datasets

def fake_lpr2_diag(fake, pcr_record):
  return {
    "RECNUM": pcr_record["RECNUM"],
    "C_DIAG": fake.random_element(elements=["00999", "11609", "42009", "DF20", "DF30", "DF25"]),
    "C_DIAGTYPE": fake.random_element(elements=["A", "B"])
  }

def fake_lpr2_adm_record(fake, bef_person):
  birth_date = datetime.datetime.strptime(bef_person["FOED_DAG"], DATE_FORMAT)
  start_date = fake.past_date(start_date=birth_date)
  end_date   = fake.past_date(start_date=start_date)

  adm = {
    "RECNUM": fake.random_int(max=9999999),
    "PNR": bef_person["PNR"],
    "C_PATTYPE": fake.random_element(elements=[0, 1, 2, 4, 5]),
    "D_INDDTO": start_date,
    "D_UDDTO": end_date
  }

  diags = []

  diagnoses_count = fake.random_int(min=0, max=2)

  for _ in range(0, diagnoses_count):
    diags.append(
      fake_lpr2_diag(fake, adm)
    )

  return (adm, diags)

def fake_lpr2_adm_diag_dataset(fake, bef_dataset):
  adm_result  = []
  diag_result = []

  for row in bef_dataset:
    records_count = fake.random_int(min=1, max=5)

    for _ in range(0, records_count):
      (adm, diags) = fake_lpr2_adm_record(fake, row)

      adm_result.append(adm)
      diag_result += diags

  return (adm_result, diag_result)

#-------------------------------------------------------------------------------
# PSYK datasets

def fake_psyk_diag(fake, pcr_record):
  return {
    "RECNUM": pcr_record["RECNUM"],
    "C_DIAG": fake.random_element(elements=["00999", "11609", "42009", "DF20", "DF30", "DF25"]),
    "C_DIAGTYPE": fake.random_element(elements=["A", "B"])
  }

def fake_psyk_adm_record(fake, bef_person):
  birth_date = datetime.datetime.strptime(bef_person["FOED_DAG"], DATE_FORMAT)
  start_date = fake.past_date(start_date=birth_date)
  end_date   = fake.past_date(start_date=start_date)

  adm = {
    "RECNUM": fake.random_int(max=9999999),
    "PNR": bef_person["PNR"],
    "C_PATTYPE": fake.random_element(elements=[0, 1, 2, 3]),
    "D_INDDTO": start_date,
    "D_UDDTO": end_date
  }

  diags = []

  diagnoses_count = fake.random_int(min=0, max=2)

  for _ in range(0, diagnoses_count):
    diags.append(
      fake_psyk_diag(fake, adm)
    )

  return (adm, diags)

def fake_psyk_adm_diag_dataset(fake, bef_dataset):
  adm_result  = []
  diag_result = []

  for row in bef_dataset:
    records_count = fake.random_int(min=1, max=5)

    for _ in range(0, records_count):
      (adm, diags) = fake_psyk_adm_record(fake, row)

      adm_result.append(adm)
      diag_result += diags

  return (adm_result, diag_result)

#-------------------------------------------------------------------------------
# LPR3 datasets

def fake_lpr3_diagnose(fake, kontakt):
  typ = fake.random_element(elements=["A", "B", "+"])

  return {
    "DW_EK_KONTAKT": kontakt["DW_EK_KONTAKT"],
    "DIAGNOSEKODE": fake.random_element(elements=["00999", "11609", "42009", "DF20", "DF30", "DF25"]),
    "DIAGNOSEKODE_PARENT": fake.random_element(elements=["00999", "11609", "42009", "DF20", "DF30", "DF25"]) if typ == "+" else "",
    "DIAGNOSETYPE": typ,
  }

def fake_lpr3_kontakter_record(fake, bef_person):
  birth_date = datetime.datetime.strptime(bef_person["FOED_DAG"], DATE_FORMAT)
  start_date = fake.past_date(start_date=birth_date)
  end_date   = fake.past_date(start_date=start_date)

  kontakt = {
    "DW_EK_KONTAKT": fake.random_int(max=9999999),
    "PNR": bef_person["PNR"],
    "KONTAKTTYPE": fake.random_element(elements=["ALCA00", "ALCA01", "ALCA03", "ALCA10", "ALCA20"]),
    "DATO_START": start_date,
    "DATO_SLUT": end_date
  }

  diagnoser = []
  diagnoses_count = fake.random_int(min=0, max=2)

  for _ in range(0, diagnoses_count):
    diagnoser.append(
      fake_lpr3_diagnose(fake, kontakt)
    )

  return (kontakt, diagnoser)

def fake_lpr3_kontakter_diagnoser_dataset(fake, bef_dataset):
  kontakter_result  = []
  diagnoser_result = []

  for row in bef_dataset:
    records_count = fake.random_int(min=1, max=5)

    for _ in range(0, records_count):
      (kontakt, diagnoser) = fake_lpr3_kontakter_record(fake, row)

      kontakter_result.append(kontakt)
      diagnoser_result += diagnoser

  return (kontakter_result, diagnoser_result)

#-------------------------------------------------------------------------------
# Utilities

def write_dataset(dataset, output_directory, name):
  csv_path = os.path.join(output_directory, f"{name}.csv")
  cols        = list(dataset[0].keys())

  logger.info(f"Writing dataset {name}")

  with open(csv_path, "w", newline="") as f:
    writer = csv.DictWriter(f, delimiter=",", quotechar="\"", quoting=csv.QUOTE_MINIMAL, fieldnames=cols, dialect="unix")
    writer.writeheader()

    for row in dataset:
      writer.writerow(row)

  sas_path = os.path.join(output_directory, f"{name}.sas7bdat")

  check_call(["./bin/csv-to-sas7bdat.R", csv_path, sas_path], cwd=PROJECT_DIR)

  logger.info(f"Dataset {name} written to file {csv_path} and {sas_path}")

  return cols

#-------------------------------------------------------------------------------

def main(args):
  fake = Faker()

  if args.random_seed:
    fake.seed_instance(args.random_seed)

  for year in ["198512", "198612"]:
    bef_dataset  = fake_bef_dataset(fake, args.bef_families_count)
    lmdb_dataset = fake_lmdb_dataset(fake, bef_dataset)
    (lpr2_adm_dataset, lpr2_diag_dataset) = fake_lpr2_adm_diag_dataset(fake, bef_dataset)
    (lpr3_kontakter_dataset, lpr3_diagnoser_dataset) = fake_lpr3_kontakter_diagnoser_dataset(fake, bef_dataset)
    (psyk_adm_dataset, psyk_diag_dataset) = fake_psyk_adm_diag_dataset(fake, bef_dataset)

    bef_cols  = write_dataset(bef_dataset, args.grund_data_dir, f"bef{year}")
    lmdb_cols = write_dataset(lmdb_dataset, args.grund_data_dir, f"lmdb{year}")
    lpr2_adm_cols = write_dataset(lpr2_adm_dataset, args.grund_data_dir, f"lpr_adm{year}")
    lpr2_diag_cols = write_dataset(lpr2_diag_dataset, args.grund_data_dir, f"lpr_diag{year}")
    lpr3_kontakter_cols = write_dataset(lpr3_kontakter_dataset, args.grund_data_dir, f"lpr_f_kontakter{year}")
    lpr3_diagnoser_cols = write_dataset(lpr3_diagnoser_dataset, args.grund_data_dir, f"lpr_f_diagnoser{year}")
    psyk_adm_cols = write_dataset(psyk_adm_dataset, args.grund_data_dir, f"psyk_adm{year}")
    psyk_diag_cols = write_dataset(psyk_diag_dataset, args.grund_data_dir, f"psyk_diag{year}")

  # These datasets are not divided by year
  pcr_patient_icd8_dataset = fake_pcr_patient_icd8_dataset(fake, bef_dataset)
  pcr_patient_icd8_cols    = write_dataset(pcr_patient_icd8_dataset, args.external_data_dir, f"patient_icd8")

  pcr_patient_icd10_dataset = fake_pcr_patient_icd10_dataset(fake, bef_dataset)
  pcr_patient_icd10_cols    = write_dataset(pcr_patient_icd10_dataset, args.external_data_dir, f"patient_icd10")

  pcr_diag_icd10_dataset = fake_pcr_diag_icd10_dataset(fake, pcr_patient_icd10_dataset)
  pcr_diag_icd10_cols    = write_dataset(pcr_diag_icd10_dataset, args.external_data_dir, f"diag_icd10")

  logger.info(f"Updating stage1 of metadata file {args.metadata_file}")

  with open(args.metadata_file, "r") as f:
    metadata = json.loads(f.read())

  metadata["stage1"] = OrderedDict({
    "bef": OrderedDict({
      "columns": bef_cols
    }),
    "lmdb": OrderedDict({
      "columns": lmdb_cols
    }),
    "lpr_adm": OrderedDict({
      "columns": lpr2_adm_cols
    }),
    "lpr_diag": OrderedDict({
      "columns": lpr2_diag_cols
    }),
    "psyk_adm": OrderedDict({
      "columns": psyk_adm_cols
    }),
    "psyk_diag": OrderedDict({
      "columns": psyk_diag_cols
    }),
    "lpr_f_kontakter": OrderedDict({
      "columns": lpr3_kontakter_cols
    }),
    "lpr_f_diagnoser": OrderedDict({
      "columns": lpr3_diagnoser_cols
    }),
    "patient_icd8": OrderedDict({
      "columns": pcr_patient_icd8_cols
    }),
    "patient_icd10": OrderedDict({
      "columns": pcr_patient_icd10_cols
    }),
    "diag_icd10": OrderedDict({
      "columns": pcr_diag_icd10_cols
    })
  })

  with open(args.metadata_file, "w") as f:
    f.write(json.dumps(metadata, indent=2))

  logger.info("All done")

if __name__ == "__main__":
  parser = argparse.ArgumentParser(prog=SCRIPT_NAME)

  parser.add_argument(
    "--log_level",
    type=str,
    choices=["error", "info", "debug"],
    help="Controls the log level, 'info' is default"
  )

  parser.add_argument(
    "--bef_families_count",
    type=int,
    default=10,
    help="Controls how many families to generate in the BEF dataset"
  )

  parser.add_argument(
    "--random_seed",
    type=int,
    help="What seed to use for the random generator"
  )

  parser.add_argument(
    "--external_data_dir",
    type=str,
    help="Directory to write external output files into"
  )

  parser.add_argument(
    "--grund_data_dir",
    type=str,
    help="Directory to write grund output files into"
  )

  parser.add_argument(
    "--metadata_file",
    type=str,
    help="Metadata file that contains the dataset to clean and what columns to use"
  )

  args = parser.parse_args()

  if args.log_level == "debug":
    stream_handler.setLevel(logging.DEBUG)
  elif args.log_level == "error":
    stream_handler.setLevel(logging.ERROR)

  main(args)
