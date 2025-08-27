//
// AMR Typing and Analysis
//

include { SNIPPY_AMR       } from '../../../modules/local/amr_profiler/snippy_amr/main'
include { DEPTH            } from '../../../modules/local/amr_profiler/depth/main'
include { VARIANT_ANALYSIS } from '../../../modules/local/amr_profiler/variant_analysis/main'
include { MLST             } from '../../../modules/local/amr_profiler/mlst/main'
include { NGMASTER         } from '../../../modules/local/amr_profiler/ngmaster/main'
include { BLASTN           } from '../../../modules/local/amr_profiler/blastn/main'
include { MERGE_SINGLE_AMR } from '../../../modules/local/amr_profiler/merge_single_amr/main'
include { MERGE_AMR        } from '../../../modules/local/amr_profiler/merge_amr/main'

workflow AMR_PROFILER {
    take:
    reads          // channel: [ meta, [ reads ] ]
    contigs        // channel: [ meta, [ contigs ] ]
    wg_bam         // channel: [ meta, [ bam ] ]
    wg_tab         // channel: [ meta, [ tab ] ]
    wg_bai         // channel: [ meta, [ bai ] ]
    prefix         // val(prefix)

    main:

    ch_versions = Channel.empty()

    //
    // Variant calling for HGT genes with Snippy
    //
    SNIPPY_AMR (
        reads,
        "${params.amr_ref}"
    )
    ch_versions = ch_versions.mix(SNIPPY_AMR.out.versions)

    //
    // Get average depth for AMR genes 
    //
    ch_depth_input = wg_bam.join(SNIPPY_AMR.out.bam).join(wg_bai).join(SNIPPY_AMR.out.bai)
    ch_depth_report = Channel.empty()
    DEPTH (
        ch_depth_input,
        "${params.loci}"
    )
    ch_depth_report = DEPTH.out.avg_depth
    //ch_versions = ch_versions.mix(DEPTH.out.versions)

    //
    // Parse variant calls and compare them to defaults for positions of interest
    //
    ch_variant_analysis_input = wg_tab.join(SNIPPY_AMR.out.tab).join(ch_depth_report).join(DEPTH.out.pos_depths)
    VARIANT_ANALYSIS (
        ch_variant_analysis_input,
        "${params.default_amr}",
        "${params.columns}",
        "${params.strands}"
    )
    ch_versions = ch_versions.mix(VARIANT_ANALYSIS.out.versions)

    //
    // Get ST for sample
    //
    MLST (
        contigs,
        "${params.pubmlst}",
        "${params.blastdb}",
        "${params.dbname}"
    )
    ch_versions = ch_versions.mix(MLST.out.versions)

    //
    // Get NGSTAR and NGMAST type
    //
    NGMASTER (
        contigs,
        "${params.ngmasterdb}",
        "${params.ngstar}",
        "${params.ngmast}"
    )
    ch_versions = ch_versions.mix(NGMASTER.out.versions)

    //
    // Run Blastn to get alleles and gene lengths
    //
    BLASTN (
        contigs,
        "${params.a_blastdb}",
        "${params.penAdb}",
        "${params.porBdb}",
        "${params.mtrR_mosaic_ref}"
    )
    //ch_versions = ch_versions.mix(BLASTN.out.versions)

    //
    // Merge reports into one AMR report for sample
    //
    ch_merge_input = VARIANT_ANALYSIS.out.report.join(BLASTN.out.blast_report).join(MLST.out.mlst_report).join(NGMASTER.out.ngmaster_report)
    ch_amr_report = Channel.empty()
    MERGE_SINGLE_AMR (
            ch_merge_input
        )
    ch_amr_report = MERGE_SINGLE_AMR.out.amr_report
    //ch_versions = ch_versions.mix(MERGE_SINGLE_AMR.out.versions)

    //
    // Merge reports for all samples to make larger AMR / depth reports
    //
    ch_depth_report = ch_depth_report
                        .map {
                            meta, depth_report ->
                            depth_report
                        }
    MERGE_AMR (
        ch_amr_report.collect(),
        ch_depth_report.collect(),
        prefix
    )
    ch_versions = ch_versions.mix(MERGE_AMR.out.versions)

    emit:

    tab                = SNIPPY_AMR.out.tab                // channel: [ meta, [ tab ] ]
    csv                = SNIPPY_AMR.out.csv                // channel: [ meta, [ csv ] ]
    html               = SNIPPY_AMR.out.html               // channel: [ meta, [ html ] ]
    vcf                = SNIPPY_AMR.out.vcf                // channel: [ meta, [ vcf ] ]
    bed                = SNIPPY_AMR.out.bed                // channel: [ meta, [ bed ] ]
    gff                = SNIPPY_AMR.out.gff                // channel: [ meta, [ gff ] ]
    bam                = SNIPPY_AMR.out.bam                // channel: [ meta, [ bam ] ]
    bai                = SNIPPY_AMR.out.bai                // channel: [ meta, [ bai ] ]    
    //log                = SNIPPY_AMR.out.log              // channel: [ meta, [ log ] ]
    aligned_fa         = SNIPPY_AMR.out.aligned_fa         // channel: [ meta, [ aligned_fa ] ]
    consensus_fa       = SNIPPY_AMR.out.consensus_fa       // channel: [ meta, [ consensus_fa ] ]
    consensus_subs_fa  = SNIPPY_AMR.out.consensus_subs_fa  // channel: [ meta, [ consensus_subs_fa ] ]
    raw_vcf            = SNIPPY_AMR.out.raw_vcf            // channel: [ meta, [ raw_vcf ] ]
    filt_vcf           = SNIPPY_AMR.out.filt_vcf           // channel: [ meta, [ filt_vcf ] ]
    vcf_gz             = SNIPPY_AMR.out.vcf_gz             // channel: [ meta, [ vcf_gz ] ]    
    vcf_csi            = SNIPPY_AMR.out.vcf_csi            // channel: [ meta, [ vcf_csi ] ]
    txt                = SNIPPY_AMR.out.txt                // channel: [ meta, [ txt ] ]

    avg_depth          = ch_depth_report                   // channel: [ meta, [ avg_depth ] ]

    report             = VARIANT_ANALYSIS.out.report       // channel: [ meta, [ report ] ]
    amr_vcf            = VARIANT_ANALYSIS.out.amr_vcf      // channel: [ meta, [ amr_vcf ] ]

    mlst_report        = MLST.out.mlst_report              // channel: [ meta, [ mlst_report ] ]

    ngmaster_report    = NGMASTER.out.ngmaster_report      // channel: [ meta, [ ngmaster_report ] ]

    blast_report       = BLASTN.out.blast_report           // channel: [ meta, [ blast_report ] ]

    amr_report         = ch_amr_report                     // channel: [ meta, [ amr_report ] ]

    all_amr            = MERGE_AMR.out.all_amr             // channel: [ all_amr ]
    all_depth          = MERGE_AMR.out.all_depth           // channel: [ all_depth ]

    versions           = ch_versions                       // channel: [ versions.yml ]
}