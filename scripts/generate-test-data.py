#!/usr/bin/env python3

import os
import logging
import argparse
import datetime
import csv
import json
import sys
from subprocess import check_call
from collections import OrderedDict
from dateutil.relativedelta import relativedelta

from faker import Faker

#-------------------------------------------------------------------------------
# Constants

SCRIPT_NAME = "generate-test-data"
DATE_FORMAT = "%Y-%m-%d"
PROJECT_DIR = os.path.realpath(os.path.dirname(os.path.dirname(__file__)))

C_DODSMAADE_VALUES = ["-", "0", "01", "02", "03", "04", "05", "06", "07", "08", "09", "1", "10", "2", "3", "4", "5", "6", "7", "8", "9", "99", ""]

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
# IND dataset

def fake_ind_record(fake, bef_person, period_date):
  birth_date             = datetime.datetime.strptime(bef_person["FOED_DAG"], DATE_FORMAT)
  relative_age           = relativedelta(period_date, birth_date).years
  social_contrib_income        = fake.random_int(min=0, max=999999)
  employment_income      = fake.random_int(min=0, max=999999)
  social_income          = fake.random_int(min=0, max=999999)
  private_pension_income = fake.random_int(min=0, max=999999) if relative_age > 65 else 0
  rest_income            = fake.random_int(min=0, max=999999)
  all_income             = employment_income + social_income + private_pension_income + rest_income
  total_taxes            = all_income * 0.38

  return {
    "PNR": bef_person["PNR"],
    "ALDER_ULT_INK": relative_age,
    "BESKST13": "08",
    "OMFANG": 1,
    "PERINDKIALT_13": social_contrib_income + social_income + private_pension_income + rest_income,
    "LOENMV_13": employment_income,
    "ERHVERVSINDK_13": social_contrib_income,
    "OFF_OVERFORSEL_13": social_income,
    "PRIVAT_PENSION_13": private_pension_income,
    "RESUINK_13": rest_income,
    "SKATTOT_13": total_taxes
  }

def fake_ind_dataset(fake, bef_dataset, period_date):
  result = []

  for row in bef_dataset:
    result.append(
      fake_ind_record(fake, row, period_date)
    )

  return result

#-------------------------------------------------------------------------------
# FAIK dataset

def fake_faik_record(fake, family, period_date):
  social_contrib_income        = fake.random_int(min=0, max=999999)
  employment_income      = fake.random_int(min=0, max=999999)
  social_income          = fake.random_int(min=0, max=999999)
  private_pension_income = fake.random_int(min=0, max=999999)
  rest_income            = fake.random_int(min=0, max=999999)
  all_income             = employment_income + social_income + private_pension_income + rest_income
  total_taxes            = all_income * 0.38

  return {
    "FAMILIE_ID": family[0]["FAMILIE_ID"],
    "FAMTYPE": 1,
    "FAMINDKOMSTIALT_13": social_contrib_income + social_income + private_pension_income + rest_income,
    "FAMLOENMV_13": employment_income,
    "FAMERHVERVSINDK_13": social_contrib_income,
    "FAMOFF_OVERFORSEL_13": social_income,
    "FAMPRIVAT_PENSION_13": private_pension_income,
    "FAMRESTINDK_13": rest_income,
    "FAMSKATTOT_13": total_taxes
  }

def fake_faik_dataset(fake, families_dataset, period_date):
  result = []

  for _, row in families_dataset.items():
    result.append(
      fake_faik_record(fake, row, period_date)
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
# Cause of death

def fake_dodsaars_record(fake, bef_person):
  birth_date = datetime.datetime.strptime(bef_person["FOED_DAG"], DATE_FORMAT)
  death_date = fake.past_date(start_date=birth_date)

  return {
    "PNR": bef_person["PNR"],
    "D_DODSDTO": death_date,
    "C_DODSMAADE": fake.random_element(elements=C_DODSMAADE_VALUES),
    "C_DOD1": fake.random_element(elements=["9523", "2990", "9869", "I709", "J449", "I251"]),
    "C_DOD2": fake.random_element(elements=["9523", "2990", "9869", "I709", "J449", "I251"]),
    "C_DOD3": fake.random_element(elements=["9523", "2990", "9869", "I709", "J449", "I251"]),
    "C_DOD4": fake.random_element(elements=["9523", "2990", "9869", "I709", "J449", "I251"])
  }

def fake_dodsaars_dataset(fake, bef_datasets):
  result = []

  for row in bef_datasets:
    result.append(
      fake_dodsaars_record(fake, row)
    )

  return result

def fake_dodsaasg_record(fake, bef_person):
  birth_date = datetime.datetime.strptime(bef_person["FOED_DAG"], DATE_FORMAT)
  death_date = fake.past_date(start_date=birth_date)

  return {
    "PNR": bef_person["PNR"],
    "D_DODSDATO": death_date,
    "C_DODSMAADE": fake.random_element(elements=C_DODSMAADE_VALUES),
    "C_DOD_1A": fake.random_element(elements=["X59", "R549", "I709", "J449", "I251"]),
    "C_DOD_1B": fake.random_element(elements=["X59", "R549", "I709", "J449", "I251"]),
    "C_DOD_1C": fake.random_element(elements=["X59", "R549", "I709", "J449", "I251"]),
    "C_DOD_1D": fake.random_element(elements=["X59", "R549", "I709", "J449", "I251"])
  }

def fake_dodsaasg_dataset(fake, bef_datasets):
  result = []

  for row in bef_datasets:
    result.append(
      fake_dodsaasg_record(fake, row)
    )

  return result

#-------------------------------------------------------------------------------
# Education

def fake_udda_record(fake, bef_person, year):
  birth_date   = datetime.datetime.strptime(bef_person["FOED_DAG"], DATE_FORMAT)
  highest_date = fake.past_date(start_date=birth_date)

  return {
    "PNR": bef_person["PNR"],
    "HFAUDD": fake.random_element(elements=["1006", "2461", "4071"]),
    "HFINSTNR": fake.random_element(elements=["101087", "615010", "751406"]),
    "HF_KILDE": fake.random_element(elements=["1", "9", "17"]),
    "HF_VFRA": highest_date,
    "UDD": fake.random_element(elements=["5189", "5166"])
  }

def fake_udda_dataset(fake, bef_datasets, year):
  result = []

  for row in bef_datasets:
    result.append(
      fake_udda_record(fake, row, year)
    )

  return result

#-------------------------------------------------------------------------------
# Employment

def fake_ras_record(fake, bef_person, year):
  result = {
    "PNR": bef_person["PNR"],
    "ARBSTIL": None,
    "NYARB": None,
    "SOCSTIL_KODE": None,
    "SOC_STATUS_KODE": None,
    "BRANCHE_77": None,
    "BRANCHE_KODE": None,
    "ARB_HOVED_BRA_DB07": None
  }

  # ARBSTIL i perioden 1980-1993
  # NYARB i perioden 1994-1995
  # SOCSTIL i perioden 1996-2008
  # Source: https://www.dst.dk/da/TilSalg/data-til-forskning/generelt-om-data/dokumentation-af-data/hoejkvalitetsvariable/befolkningens-tilknytning-til-arbejdsmarkedet--ras-/arbstil
  # The variable SOCSTATUSKODE exists from 2008 onwards. The variable replaces the previous SOCSTILKODE
  # Soruce: https://www.dst.dk/da/TilSalg/data-til-forskning/generelt-om-data/dokumentation-af-data/hoejkvalitetsvariable/befolkningens-tilknytning-til-arbejdsmarkedet--ras-/soc-status-kode
  if year <= 1993:
    result["ARBSTIL"] = fake.random_element(elements=[11, 12, 13, 14, 20, 31, 32, 40, 50, 92])
  elif year >= 1994 and year <= 1995:
    result["NYARB"] = fake.random_element(elements=[11, 12, 13, 14, 20, 31, 32, 40, 50, 92])
  elif year >= 1996 and year <= 2007:
    result["SOCSTIL_KODE"] = fake.random_element(elements=[115, 118, 130, 200, 316, 400])
  else:
    result["SOC_STATUS_KODE"] = fake.random_element(elements=[115, 118, 130, 200, 316, 612])

  # Dansk branchekode 1977 til 1993
  # Source: https://www.dst.dk/da/Statistik/dokumentation/Times/Personindkomst/BRANCHE-77
  if year <= 1992:
    result["BRANCHE_77"] = fake.random_element(elements=["00000", "10000", "34199", "99999"])
  elif year >= 1992 and year <= 2007:
    # Gyldig fra: 01-01-1992
    # Gyldig til: 31-12-2007
    # Source: https://www.dst.dk/da/TilSalg/data-til-forskning/generelt-om-data/dokumentation-af-data/hoejkvalitetsvariable/beskaeftigede-personer--ras-/branche-kode
    result["BRANCHE_KODE"] = fake.random_element(elements=[34199, 174090, 182210])
  else:
    # Gyldig fra: 1. januar 2008
    # Source: https://www.dst.dk/da/Statistik/dokumentation/nomenklaturer/db07?id=28e4a8f7-1495-4563-9f8d-1de8587305de
    result["ARB_HOVED_BRA_DB07"] = fake.random_element(elements=["011100", "641100", "771100", "851000"])

  return result

def fake_ras_dataset(fake, bef_datasets, year):
  result = []

  for row in bef_datasets:
    result.append(
      fake_ras_record(fake, row, year)
    )

  return result

def fake_akm_record(fake, bef_person, year):
  return {
    "PNR": bef_person["PNR"],
    "SOCIO": fake.random_element(elements=[0, 11, 322]),
    "SOCIO_GL": fake.random_element(elements=[0, 11, 999]),
    "SOCIO02": fake.random_element(elements=[0, 111, 330]),
    "SOCIO13": fake.random_element(elements=[0, 113, 420])
  }

def fake_akm_dataset(fake, bef_datasets, year):
  result = []

  for row in bef_datasets:
    result.append(
      fake_ras_record(fake, row, year)
    )

  return result

#-------------------------------------------------------------------------------
# Utilities

def mk_families_dataset(bef_dataset):
  result = {}
  id_col = "FAMILIE_ID"

  for row in bef_dataset:
    family_id = row[id_col]

    if family_id in result:
      result[family_id].append(row)
    else:
      result[family_id] = [row]

  return result

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

  for year in [1985, 1993, 2008, 2020]:
    period = f"{year}12"
    period_date = datetime.datetime(year, 12, 31, 23, 59, 59)

    bef_dataset      = fake_bef_dataset(fake, args.bef_families_count)
    lmdb_dataset     = fake_lmdb_dataset(fake, bef_dataset)
    ind_dataset      = fake_ind_dataset(fake, bef_dataset, period_date)
    dodsaars_dataset = fake_dodsaars_dataset(fake, bef_dataset)
    dodsaasg_dataset = fake_dodsaasg_dataset(fake, bef_dataset)
    families_dataset = mk_families_dataset(bef_dataset)
    faik_dataset     = fake_faik_dataset(fake, families_dataset, period_date)
    udda_dataset     = fake_udda_dataset(fake, bef_dataset, year)
    ras_dataset      = fake_ras_dataset(fake, bef_dataset, year)
    akm_dataset      = fake_akm_dataset(fake, bef_dataset, year)

    (lpr2_adm_dataset, lpr2_diag_dataset) = fake_lpr2_adm_diag_dataset(fake, bef_dataset)
    (lpr3_kontakter_dataset, lpr3_diagnoser_dataset) = fake_lpr3_kontakter_diagnoser_dataset(fake, bef_dataset)
    (psyk_adm_dataset, psyk_diag_dataset) = fake_psyk_adm_diag_dataset(fake, bef_dataset)

    bef_cols            = write_dataset(bef_dataset, args.grund_data_dir, f"bef{period}")
    lmdb_cols           = write_dataset(lmdb_dataset, args.grund_data_dir, f"lmdb{period}")
    ind_cols            = write_dataset(ind_dataset, args.grund_data_dir, f"ind{year}")
    dodsaars_cols       = write_dataset(dodsaars_dataset, args.grund_data_dir, f"dodsaars{year}")
    dodsaasg_cols       = write_dataset(dodsaasg_dataset, args.grund_data_dir, f"dodsaasg{year}")
    faik_cols           = write_dataset(faik_dataset, args.grund_data_dir, f"faik{year}")
    udda_cols           = write_dataset(udda_dataset, args.grund_data_dir, f"udda{year}")
    ras_cols            = write_dataset(ras_dataset, args.grund_data_dir, f"ras{year}")
    akm_cols            = write_dataset(akm_dataset, args.grund_data_dir, f"akm{year}")
    lpr2_adm_cols       = write_dataset(lpr2_adm_dataset, args.grund_data_dir, f"lpr_adm{year}")
    lpr2_diag_cols      = write_dataset(lpr2_diag_dataset, args.grund_data_dir, f"lpr_diag{year}")
    lpr3_kontakter_cols = write_dataset(lpr3_kontakter_dataset, args.grund_data_dir, f"lpr_f_kontakter{year}")
    lpr3_diagnoser_cols = write_dataset(lpr3_diagnoser_dataset, args.grund_data_dir, f"lpr_f_diagnoser{year}")
    psyk_adm_cols       = write_dataset(psyk_adm_dataset, args.grund_data_dir, f"psyk_adm{year}")
    psyk_diag_cols      = write_dataset(psyk_diag_dataset, args.grund_data_dir, f"psyk_diag{year}")

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
    "ind": OrderedDict({
      "columns": ind_cols
    }),
    "dodsaars": OrderedDict({
      "columns": dodsaars_cols
    }),
    "dodsaasg": OrderedDict({
      "columns": dodsaasg_cols
    }),
    "faik": OrderedDict({
      "columns": faik_cols
    }),
    "udda": OrderedDict({
      "columns": udda_cols
    }),
    "ras": OrderedDict({
      "columns": ras_cols
    }),
    "akm": OrderedDict({
      "columns": akm_cols
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
