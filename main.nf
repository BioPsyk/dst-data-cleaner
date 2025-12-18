#!/usr/bin/env nextflow

nextflow.preview.output = true
nextflow.enable.strict  = true

Settings.init(params)

include { stage1 } from "./workflows/stage1"
include { stage2 } from "./workflows/stage2"

def grundDataDir    = Settings.param("grund_data_dir", Directory).value
def externalDataDir = Settings.param("external_data_dir", Directory).value
def outputDir       = Settings.param("output_dir", Directory).value
def metadata        = new groovy.json.JsonSlurper().parseText(
  new File("./metadata.json").text
)

workflow {
  stage1(
    metadata["stage1"],
    channel.fromPath(grundDataDir.absolutePath + "/*.sas7bdat", type: "file"),
    channel.fromPath(externalDataDir.absolutePath + "/*.sas7bdat", type: "file")
  ) | stage2
}

output {
  directory outputDir.toString()

  "stage1/grund" { mode "copy" }
  "stage1/external" { mode "copy" }
  "stage2" { mode "copy" }
}
