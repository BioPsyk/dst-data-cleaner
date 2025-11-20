#!/usr/bin/env nextflow

nextflow.preview.output = true
nextflow.enable.strict  = true

Settings.init(params)

include { stage1 } from "./workflows/stage1"

def dataDir   = Settings.param("data-dir", Directory).value
def outputDir = Settings.param("output-dir", Directory).value
def metadata  = new groovy.json.JsonSlurper().parseText(
  new File("./metadata.json").text
)

workflow {
  stage1(
    metadata["stage1"],
    channel.fromPath(dataDir.absolutePath + "/*.sas7bdat", type: "file")
  )

  stage1.out | view
}

output {
  directory outputDir.toString()

  "stage1/csv" { mode "copy" }
}
