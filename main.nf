#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/neissflow
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/neissflow
    Website: https://nf-co.re/neissflow
    Slack  : https://nfcore.slack.com/channels/neissflow
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { NEISSFLOW  } from './workflows/neissflow'
include { QC  } from './workflows/QC'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_neissflow_pipeline'
include { fromSamplesheet         } from 'plugin/nf-validation'
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
workflow NFCORE_NEISSFLOW {

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
    multiqc_report = NEISSFLOW.out.multiqc_report

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
        params.help,
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
            .fromSamplesheet("controls")
            .map {
                meta, fastq_1, fastq_2 ->
                    [ meta.id, [ fastq_1, fastq_2 ] ]
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
    NFCORE_NEISSFLOW (
        PIPELINE_INITIALISATION.out.samplesheet
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        NFCORE_NEISSFLOW.out.multiqc_report
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
