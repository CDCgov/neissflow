#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CDCgov/neissflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/CDCgov/neissflow
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { NEISSFLOW               } from './workflows/neissflow'
include { QC                      } from './workflows/QC'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_neissflow_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_neissflow_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run QC pipeline 
//
workflow NEISSFLOW_QC {

    take:
    samplesheet // channel: samplesheet read in from QC profile
    

    main:

    //
    // WORKFLOW: Run pipeline
    //
    QC (
        samplesheet
    )

    emit:
    multiqc_report = QC.out.multiqc_report

}

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow CDCGOV_NEISSFLOW {

    take:
    samplesheet // channel: samplesheet read in from --input

    main:

    //
    // WORKFLOW: Run pipeline
    //
    NEISSFLOW (
        samplesheet
    )
    emit:
    multiqc_report = NEISSFLOW.out.multiqc_report // channel: /path/to/multiqc_report.html
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.input
    )

    if (params.QC && !params.only_fasta){
        //
        // Create channel from control samples file provided through QC profile (params.controls)
        //
        Channel
            .fromList(samplesheetToList(params.controls, "${projectDir}/assets/schema_controls.json"))
            .map {
                meta, fastq_1, fastq_2 ->
                    [ meta, [ fastq_1, fastq_2 ] ]
            }
            .set { ch_control_samplesheet }
        
        
        //
        // WORKFLOW: Run QC workflow
        //
        NEISSFLOW_QC (
            ch_control_samplesheet
        )
    }

    //
    // WORKFLOW: Run main workflow
    //
    CDCGOV_NEISSFLOW (
        PIPELINE_INITIALISATION.out.samplesheet
    )
    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.outdir,
        params.monochrome_logs,
        CDCGOV_NEISSFLOW.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
