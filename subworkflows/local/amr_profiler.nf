//
// AMR Typing and Analysis
//

include { SNIPPY_AMR       } from '../../modules/local/snippy_amr'
include { DEPTH            } from '../../modules/local/depth'
include { VARIANT_ANALYSIS } from '../../modules/local/variant_analysis'
include { MLST             } from '../../modules/local/mlst'
include { NGMASTER         } from '../../modules/local/ngmaster'
include { BLASTN           } from '../../modules/local/blastn'
include { MERGE_SINGLE_AMR } from '../../modules/local/merge_single_amr'
include { MERGE_AMR        } from '../../modules/local/merge_amr'

workflow AMR_PROFILER {
    take:
    reads          // channel: [ val(sample_name), [ reads ] ]
    contigs        // channel: [ val(sample_name), [ contigs ] ]
    wg_bam         // channel: [ val(sample_name), [ bam ] ]
    wg_tab         // channel: [ val(sample_name), [ tab ] ]
    wg_bai         // channel: [ val(sample_name), [ bai ] ]
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
        "${params.columns}"
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

    tab                = SNIPPY_AMR.out.tab                // channel: [ val(sample_name), [ tab ] ]
    csv                = SNIPPY_AMR.out.csv                // channel: [ val(sample_name), [ csv ] ]
    html               = SNIPPY_AMR.out.html               // channel: [ val(sample_name), [ html ] ]
    vcf                = SNIPPY_AMR.out.vcf                // channel: [ val(sample_name), [ vcf ] ]
    bed                = SNIPPY_AMR.out.bed                // channel: [ val(sample_name), [ bed ] ]
    gff                = SNIPPY_AMR.out.gff                // channel: [ val(sample_name), [ gff ] ]
    bam                = SNIPPY_AMR.out.bam                // channel: [ val(sample_name), [ bam ] ]
    bai                = SNIPPY_AMR.out.bai                // channel: [ val(sample_name), [ bai ] ]    
    //log                = SNIPPY_AMR.out.log                // channel: [ val(sample_name), [ log ] ]
    aligned_fa         = SNIPPY_AMR.out.aligned_fa         // channel: [ val(sample_name), [ aligned_fa ] ]
    consensus_fa       = SNIPPY_AMR.out.consensus_fa       // channel: [ val(sample_name), [ consensus_fa ] ]
    consensus_subs_fa  = SNIPPY_AMR.out.consensus_subs_fa  // channel: [ val(sample_name), [ consensus_subs_fa ] ]
    raw_vcf            = SNIPPY_AMR.out.raw_vcf            // channel: [ val(sample_name), [ raw_vcf ] ]
    filt_vcf           = SNIPPY_AMR.out.filt_vcf           // channel: [ val(sample_name), [ filt_vcf ] ]
    vcf_gz             = SNIPPY_AMR.out.vcf_gz             // channel: [ val(sample_name), [ vcf_gz ] ]    
    vcf_csi            = SNIPPY_AMR.out.vcf_csi            // channel: [ val(sample_name), [ vcf_csi ] ]
    txt                = SNIPPY_AMR.out.txt                // channel: [ val(sample_name), [ txt ] ]

    avg_depth          = ch_depth_report                     // channel: [ val(sample_name), [ avg_depth ] ]

    report             = VARIANT_ANALYSIS.out.report        // channel: [ val(sample_name), [ report ] ]
    amr_vcf            = VARIANT_ANALYSIS.out.amr_vcf       // channel: [ val(sample_name), [ amr_vcf ] ]

    mlst_report        = MLST.out.mlst_report               // channel: [ val(sample_name), [ mlst_report ] ]

    ngmaster_report    = NGMASTER.out.ngmaster_report       // channel: [ val(sample_name), [ ngmaster_report ] ]

    blast_report       = BLASTN.out.blast_report            // channel: [ val(sample_name), [ blast_report ] ]

    amr_report         = ch_amr_report                      // channel: [ val(sample_name), [ amr_report ] ]

    all_amr            = MERGE_AMR.out.all_amr              // channel: [ all_amr ]
    all_depth          = MERGE_AMR.out.all_depth            // channel: [ all_depth ]

    versions           = ch_versions                        // channel: [ versions.yml ]
}