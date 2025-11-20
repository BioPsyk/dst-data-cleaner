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

def fake_bef_family(fake):
  family_id = fake.random_int(max=9999999)
  address_id = fake.random_int(max=9999999)

  mother = {
    "PNR": fake.random_int(max=9999999),
    "MOR_ID": "",
    "FAR_ID": "",
    "FAMILIE_ID": family_id,
    "ADRESSE_ID": address_id,
    "FOED_DAG": fake.past_date(start_date='-40y').strftime(DATE_FORMAT),
    "FOEDREG_KODE": fake.random_int(min=1, max=9999),
    "KOEN": 2,
  }

  father = {
    "PNR": fake.random_int(max=9999999),
    "MOR_ID": "",
    "FAR_ID": "",
    "FAMILIE_ID": family_id,
    "ADRESSE_ID": address_id,
    "FOED_DAG": fake.past_date(start_date='-40y').strftime(DATE_FORMAT),
    "FOEDREG_KODE": fake.random_int(min=1, max=9999),
    "KOEN": 1,
  }

  child = {
    "PNR": fake.random_int(max=9999999),
    "MOR_ID": mother["PNR"],
    "FAR_ID": father["PNR"],
    "FAMILIE_ID": family_id,
    "ADRESSE_ID": address_id,
    "FOED_DAG": fake.past_date(start_date='-20y').strftime(DATE_FORMAT),
    "FOEDREG_KODE": fake.random_int(min=1, max=9999),
    "KOEN": fake.random_int(min=1, max=2),
  }

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
    result.append(
      fake_lmdb_prescription(fake, row)
    )

  return result

#-------------------------------------------------------------------------------
# Utilities

def write_dataset(dataset, output_directory, name):
  csv_path = os.path.join(args.output_directory, f"{name}.csv")
  cols        = list(dataset[0].keys())

  logger.info(f"Writing dataset {name}")

  with open(csv_path, "w", newline="") as f:
    writer = csv.DictWriter(f, delimiter=",", quotechar="\"", quoting=csv.QUOTE_MINIMAL, fieldnames=cols, dialect="unix")
    writer.writeheader()

    for row in dataset:
      writer.writerow(row)

  sas_path = os.path.join(args.output_directory, f"{name}.sas7bdat")

  check_call(["./bin/csv-to-sas7bdat.R", csv_path, sas_path], cwd=PROJECT_DIR)

  logger.info(f"Dataset {name} written to file {csv_path} and {sas_path}")

  return cols

#-------------------------------------------------------------------------------

def main(args):
  fake = Faker()

  if args.random_seed:
    fake.seed_instance(args.random_seed)

  bef_dataset  = fake_bef_dataset(fake, args.bef_families_count)
  lmdb_dataset = fake_lmdb_dataset(fake, bef_dataset)

  bef_cols  = write_dataset(bef_dataset, args.output_directory, "bef198512")
  lmdb_cols = write_dataset(lmdb_dataset, args.output_directory, "lmdb198512")

  logger.info(f"Updating stage1 of metadata file {args.metadata_file}")

  with open(args.metadata_file, "r") as f:
    metadata = json.loads(f.read())

  metadata["stage1"] = OrderedDict({
    "BEF": OrderedDict({
      "columns": bef_cols
    }),
    "LMDB": OrderedDict({
      "columns": lmdb_cols
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
    "--output_directory",
    type=str,
    help="Directory to write output files into"
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
