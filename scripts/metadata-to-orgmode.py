#!/usr/bin/env python3

import argparse
import json
import logging
import os
import sys
import tempfile
import subprocess

from tabulate import tabulate

#-------------------------------------------------------------------------------
# Constants

SCRIPT_NAME = "metadata-to-orgmode"
SCRIPT_PATH = os.path.realpath(__file__)
SCRIPT_DIR  = os.path.dirname(SCRIPT_PATH)
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)

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
# Main tasks

def read_metadata_files(metadata_dir):
  results = {}

  for fname in os.listdir(args.metadata_dir):
    if not fname.endswith("_metadata.json"):
      continue

    fpath = os.path.join(args.metadata_dir, fname)

    if not os.path.isfile(fpath):
      continue

    with open(fpath, "r") as f:
      name = fname.replace("_metadata.json", "")
      results[name] = json.loads(f.read())

  return results

def dataset_to_org_table(dataset):
  header = ["index", "name", "description"]
  rows   = []

  for key, col in dataset["columns"].items():
    rows.append([
      col["index"], f"`{key}`", col["description"]
    ])

  rows = sorted(rows, key=lambda row: row[0])

  return tabulate(rows, header, tablefmt="orgtbl")

def dataset_to_plantuml(dataset_key, dataset_name, dataset):
  result = f"""@startuml
skinparam dpi 300
skinparam shadowing false
skinparam monochrome true
skinparam padding 5
skinparam nodesep 80
skinparam ranksep 80
skinparam defaultTextAlignment center

"""

#' lpr_diag::RECNUM -RIGHT-> lpr_adm::RECNUM : " Belongs to""""

  dataset_map     = f"map \"<b>{dataset_name}</b>\" as {dataset_key} {{\n"
  column_rels     = ""
  target_datasets = {}

  for col_key, col in dataset["columns"].items():
    dataset_map += f"  {col_key} => {col["title"]}\n"

    if "relations" not in col:
      continue

    if isinstance(col["relations"], dict):
      col["relations"] = [col["relations"]]

    for rel in col["relations"]:
      if not rel["target"].startswith("urn:column"):
        continue

      (_, _, publisher, ext_ds, ext_col) = rel["target"].split(":")

      if ext_ds not in target_datasets:
        target_datasets[ext_ds] = {}

      target_datasets[ext_ds][ext_col] = {
        "title": col["title"]
      }

      column_rels += f"{ext_ds}::{ext_col} -RIGHT-> {dataset_key}::{col_key}\n"

  dataset_map += "}\n"

  for target_key, target in target_datasets.items():
    result += f"map \"<b>{target_key}</b>\" as {target_key} {{\n"

    for col_key, col in target.items():
      result += f"  {col_key} => .\n"

    result += "}\n\n"

  result += dataset_map
  result += "\n" + column_rels

  return result

def dataset_to_org_document(key, name, dataset):
  logger.info("Processing dataset %s", key)
  columns  = dataset_to_org_table(dataset)
  results = f"""* Dataset `{key}`

{dataset["description"]}

** Columns

{columns}

[[file:./images/{key}_column_diagram.png]]
  """

  return results

def generate_plantuml_diagram(plantuml, out_path):
  with open(out_path, "wb") as f:
    proc = subprocess.run(
      ["plantuml", "--pipe", "--format", "png"],
      input=plantuml.encode("utf-8"),
      stdout=subprocess.PIPE
    )

    assert proc.returncode == 0

    f.write(proc.stdout)

def main(args):
  logger.info("Looking for metadata files in %s", args.metadata_dir)

  metadata = read_metadata_files(args.metadata_dir)

  os.chdir(PROJECT_DIR)

  out_dir   = "./docs/datasets"
  doc_paths = {}

  if not os.path.exists(out_dir):
    os.makedirs(os.path.join(out_dir, "images"))

  for key, dataset in metadata.items():
    name         = key.replace("_", " ")
    name         = name[0].upper() + name[1:]
    doc_path     = os.path.join(out_dir, f"{key}.org")
    diagram_path = os.path.join(out_dir, "images", f"{key}_column_diagram.png")

    doc      = dataset_to_org_document(key, name, dataset)
    plantuml = dataset_to_plantuml(key, name, dataset)

    generate_plantuml_diagram(plantuml, diagram_path)

    with open(doc_path, "w") as f:
      f.write(doc)

    doc_paths[name] = doc_path

  logger.info("All org files created, here's a markdown link list to put in the README:")

  for key, doc_path in doc_paths.items():
    print(f"- [{key}]({doc_path})")

#-------------------------------------------------------------------------------

if __name__ == "__main__":
  parser = argparse.ArgumentParser(prog=SCRIPT_NAME)

  parser.add_argument(
    "--log_level",
    type=str,
    choices=["error", "info", "debug"],
    help="Controls the log level, 'info' is default"
  )

  parser.add_argument(
    "--metadata_dir",
    type=str,
    help="Path to directory that contains the metadata files"
  )

  args = parser.parse_args()

  if args.log_level == "debug":
    stream_handler.setLevel(logging.DEBUG)
  elif args.log_level == "error":
    stream_handler.setLevel(logging.ERROR)

  main(args)
