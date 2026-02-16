#!/usr/bin/env python3

import os
import logging
import argparse
import json

from tabulate import tabulate

#-------------------------------------------------------------------------------
# Constants

SCRIPT_NAME = "metadata-to-docs"
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

def dataset_columns_to_markdown_table(columns):
  header = ["index", "name", "description"]
  rows   = []

  for key, col in columns.items():
    rows.append([
      col["index"], f"`{key}`", col["description"]
    ])

  rows = sorted(rows, key=lambda row: row[0])

  return tabulate(rows, header, tablefmt="github")

def dataset_to_markdown_document(key, name, dataset):
  logger.info("Processing dataset %s", key)
  columns = dataset_columns_to_markdown_table(dataset["columns"])

  results = f"""# Dataset `{key}`

{dataset["description"]}

## Columns

{columns}
  """

  return results

def main(args):
  logger.info("Looking for metadata files in %s", args.metadata_dir)

  metadata = read_metadata_files(args.metadata_dir)

  os.chdir(PROJECT_DIR)

  out_paths = {}

  for key, dataset in metadata.items():
    name     = key.replace("_", " ")
    name     = name[0].upper() + name[1:]
    out_path = os.path.join("./docs/datasets", f"{key}.md")
    doc      = dataset_to_markdown_document(key, name, dataset)

    with open(out_path, "w") as f:
      f.write(doc)

    out_paths[name] = out_path

  logger.info("All markdown files created, here's a markdown link list to put in the README:")

  for key, opath in out_paths.items():
    print(f"- [{key}]({opath})")

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
