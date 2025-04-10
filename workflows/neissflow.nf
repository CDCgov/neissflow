/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//if (params.input)      { ch_input      = file(params.input)      } else { exit 1, 'Sample sheet was not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { CHECK_FASTQS           } from '../modules/local/check_fastqs'
include { SNIPPY                 } from '../modules/local/snippy'
include { SNIPPY as ALT_SNIPPY   } from '../modules/local/snippy'
include { INITIAL_MERGE          } from '../modules/local/qc_check/initial_merge'
include { QC_CHECK               } from '../modules/local/qc_check/qc_check'
include { MERGE_REPORTS          } from '../modules/local/merge/merge'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { paramsSummaryMap       } from 'plugin/nf-validation'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_neissflow_pipeline'

include { PREPROCESSING } from '../subworkflows/local/preprocessing'
include { ASSEMBLY      } from '../subworkflows/local/assembly'
include { SPECIES_CHECK } from '../subworkflows/local/species_check'
include { AMR_PROFILER  } from '../subworkflows/local/amr_profiler'
include { PHYLOGENY     } from '../subworkflows/local/phylogeny'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow NEISSFLOW {

    take:
    ch_samplesheet

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    ch_input = Channel.empty()
    ch_contigs = Channel.empty()

    //Just assembly input
    if (params.only_fasta){
        ch_contigs = ch_samplesheet
                        .map {
                            meta, fasta ->
                            return [ meta, fasta ]
                        }
    } 
    //Read and assembly input (assume raw reads unless user specifically skips preprocessing)
    else if (params.fastq_w_fasta){
        ch_contigs = ch_samplesheet
                        .map {
                            meta, files ->
                            def ( fastq_1, fastq_2, fasta ) = files
                            return [ meta, fasta ]
                        }
        ch_input = ch_samplesheet
                        .map {
                            meta, files ->
                            def ( fastq_1, fastq_2, fasta ) = files
                            return [ meta, [ fastq_1, fastq_2 ] ]
                        }
    }
    //Only read input 
    else {
        ch_input = ch_samplesheet
    }

    
    if (!params.skip_fastq_check && !params.only_fasta){
        CHECK_FASTQS (
            ch_input
        )
        ch_input = CHECK_FASTQS.out.pass
    }

    if (!params.skip_preprocess && !params.only_fasta){
        //
        // SUBWORKFLOW: Preprocess reads and run quality check 
        //
        PREPROCESSING (
            ch_input,
            "neissflow"
        )
        ch_versions = ch_versions.mix(PREPROCESSING.out.versions)
        ch_input = PREPROCESSING.out.trimmed_fastq_paths
        ch_multiqc_files = ch_multiqc_files.mix(PREPROCESSING.out.fastp_json.collect{it[1]})
    }
    //
    // Variant calling with Snippy
    //
    ch_vcf = Channel.empty()
    ch_aligned_fa = Channel.empty()
    if (!params.only_fasta){
        // if FASTQ files were input, use those
        if(params.reference_genome && ( !params.skip_amr || !params.skip_species_id )){
            // The AMR profiler step requires that FA19 be used as the ref even if another is provided
            // Species ID is also based on coverage of FA19
            ALT_SNIPPY (
                ch_input,
                params.reference_genome
            )
            SNIPPY (
                ch_input,
                params.FA19_ref
            )
            ch_multiqc_files = ch_multiqc_files.mix(ALT_SNIPPY.out.txt.collect{it[1]})
            ch_vcf = ALT_SNIPPY.out.vcf
            ch_aligned_fa = ALT_SNIPPY.out.aligned_fa
        }
        else if (params.reference_genome && params.skip_amr && params.skip_species_id) {
            SNIPPY (
                ch_input,
                params.reference_genome
            )
            ch_vcf = SNIPPY.out.vcf
            ch_aligned_fa = SNIPPY.out.aligned_fa
        } else {
            SNIPPY (
                ch_input,
                params.FA19_ref
            )
            ch_vcf = SNIPPY.out.vcf
            ch_aligned_fa = SNIPPY.out.aligned_fa
        }
    } else {
        //only use contigs if that's all we have
        if(params.reference_genome && ( !params.skip_amr || !params.skip_species_id )){
            // The AMR profiler step requires that FA19 be used as the ref even if another is provided
            // Species ID is also based on coverage of FA19
            ALT_SNIPPY (
                ch_contigs,
                params.reference_genome
            )
            SNIPPY (
                ch_contigs,
                params.FA19_ref
            )
            ch_multiqc_files = ch_multiqc_files.mix(ALT_SNIPPY.out.txt.collect{it[1]})
            ch_vcf = ALT_SNIPPY.out.vcf
            ch_aligned_fa = ALT_SNIPPY.out.aligned_fa
        }
        else if (params.reference_genome && params.skip_amr && params.skip_species_id) {
            SNIPPY (
                ch_contigs,
                params.reference_genome
            )
            ch_vcf = SNIPPY.out.vcf
            ch_aligned_fa = SNIPPY.out.aligned_fa
        } else {
            SNIPPY (
                ch_contigs,
                params.FA19_ref
            )
            ch_vcf = SNIPPY.out.vcf
            ch_aligned_fa = SNIPPY.out.aligned_fa
        }
    }
    ch_multiqc_files = ch_multiqc_files.mix(SNIPPY.out.txt.collect{it[1]})
    ch_versions = ch_versions.mix(SNIPPY.out.versions)

    //
    // SUBWORKFLOW: shovill assembly & assembly QC
    //
    if (!params.skip_assembly && params.only_fastq){
        ch_contigs = Channel.empty()
        ASSEMBLY(
            ch_input,
            ch_contigs,
            "neissflow"
        )
        ch_contigs = ASSEMBLY.out.contigs
        ch_multiqc_files = ch_multiqc_files.mix(ASSEMBLY.out.quast_results.collect{it[1]})
        ch_versions = ch_versions.mix(ASSEMBLY.out.versions)
    } else if (!params.only_fastq){
        if (params.only_fasta) {
            ch_input = Channel.empty()
        }
        ASSEMBLY(
            ch_input,
            ch_contigs,
            "neissflow"
        )
        ch_multiqc_files = ch_multiqc_files.mix(ASSEMBLY.out.quast_results.collect{it[1]})
        ch_versions = ch_versions.mix(ASSEMBLY.out.versions)
    }


    if (!params.skip_species_id && !params.only_fasta){

        ch_stats_input = SNIPPY.out.bam.join(SNIPPY.out.bai)

        //
        // Check species via alignment with FA19 and Mash results
        //
        SPECIES_CHECK (
            ch_input,
            ch_stats_input,
            "neissflow"
        )
        ch_versions = ch_versions.mix(SPECIES_CHECK.out.versions)

        if (!params.skip_preprocess && ((!params.skip_assembly && params.only_fastq) | !params.only_fastq) ){
            //
            // Merge reports generated so far to perform Neissflow QC check
            //
            INITIAL_MERGE (
                PREPROCESSING.out.fastp_report,
                SPECIES_CHECK.out.top_hits,
                SPECIES_CHECK.out.cov,
                ASSEMBLY.out.qc_stats_report
            )
            //ch_versions = ch_versions.mix(INITIAL_MERGE.out.versions)

            //
            // Neissflow QC check
            //
            QC_CHECK (
                INITIAL_MERGE.out.report,
                "neissflow"
            )
            ch_versions = ch_versions.mix(QC_CHECK.out.versions)

            ch_qc = Channel.empty()
            ch_qc = QC_CHECK.out
                    .passed
                    .splitCsv ( header:true, sep:'\t' )
                    .map { row -> "${row.ID}" }

            ch_qc = ch_qc
                    .map {
                        meta ->
                            [ meta ]
                    }
            
            ch_passed_vcf = Channel.empty()
            ch_passed_vcf = ch_vcf.join(ch_qc)

            ch_passed_aligned_fa = Channel.empty()
            ch_passed_aligned_fa = ch_aligned_fa.join(ch_qc)

            ch_passed_fq = Channel.empty()
            ch_passed_fq = ch_input.join(ch_qc)

            ch_passed_fa = Channel.empty()
            ch_passed_fa = ch_contigs.join(ch_qc)

            ch_input = ch_passed_fq
            ch_contigs = ch_passed_fa
            ch_vcf = ch_passed_vcf
            ch_aligned_fa = ch_passed_aligned_fa
        }
        
    }

    if (!params.skip_amr && !params.only_fasta){
        //
        // SUBWORKFLOW: AMR Typing and Analysis
        //
        AMR_PROFILER(
            ch_input,
            ch_contigs,
            SNIPPY.out.bam,
            SNIPPY.out.tab,
            SNIPPY.out.bai,
            "neissflow"
        )
        ch_multiqc_files = ch_multiqc_files.mix(AMR_PROFILER.out.txt.collect{it[1]})
        ch_versions = ch_versions.mix(AMR_PROFILER.out.versions)
    }

    if (!params.skip_preprocess && !params.skip_species_id && !params.skip_amr && !params.only_fasta){
        //
        // Merge reports into final report
        //
        MERGE_REPORTS(
            INITIAL_MERGE.out.report,
            AMR_PROFILER.out.all_amr,
            AMR_PROFILER.out.all_depth,
            SPECIES_CHECK.out.contams,
            SPECIES_CHECK.out.plasmids,
            PREPROCESSING.out.passed,
            QC_CHECK.out.passed,
            "${params.name}"
        )
        //ch_versions = ch_versions.mix(MERGE_REPORTS.out.versions)
    }

    if (!params.skip_phylogeny){
        ch_samples = ch_vcf 
                        .map {
                            meta, vcf ->
                            meta
                        }
                        .collect()
        ch_vcf = ch_vcf
                    .map {
                        meta, vcf ->
                        vcf
                    }
                    .collect()
        ch_aligned_fa = ch_aligned_fa
                            .map {
                                meta, aligned_fa ->
                                aligned_fa
                            }
                            .collect()

        PHYLOGENY(
            ch_vcf,
            ch_aligned_fa,
            ch_samples
        )
        ch_multiqc_files = ch_multiqc_files.mix(PHYLOGENY.out.txt.collect{it})
        ch_versions = ch_versions.mix(PHYLOGENY.out.versions)
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_pipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))

    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList()
    )


    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}
