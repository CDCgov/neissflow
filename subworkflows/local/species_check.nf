//
// Check species via alignment with FA19 and Mash results
//
include { MASH                 } from '../../modules/local/mash/mash'
include { STATS                } from '../../modules/local/stats/stats'
include { COVERAGE             } from '../../modules/local/stats/coverage'
include { COMBINE_MASH_REPORTS } from '../../modules/local/mash/combine_mash_reports'

workflow SPECIES_CHECK {
    take:
    reads          // channel: [ val(sample_name), [ reads ] ]
    ch_stats_input // channel: [ val(sample_name), bam, bai ]
    prefix         // val(prefix)

    main:

    ch_versions = Channel.empty()
    //
    // Species identification with Mash
    //
    MASH (
        reads
    )
    ch_versions = ch_versions.mix(MASH.out.versions)

    //
    // Parse Mash report to identify top hit, non-Neisseria contaminants, and plasmids
    //
    COMBINE_MASH_REPORTS (
        MASH.out.mash_results.collect(),
        prefix
    )
    ch_versions = ch_versions.mix(COMBINE_MASH_REPORTS.out.versions)

    //
    // Get alignment statistics with Samtools stats
    //
    STATS (
        ch_stats_input
    )
    ch_versions = ch_versions.mix(STATS.out.versions)

    //
    // Get percent of reference with >10x depth 
    //
    COVERAGE (
        STATS.out.stats_out.collect(),
        prefix
    )
    ch_versions = ch_versions.mix(COVERAGE.out.versions)

    emit:

    mash_reports        = MASH.out.mash_results                         // channel:  [ val(sample_name), mash_report ] 

    top_hits            = COMBINE_MASH_REPORTS.out.top_hits             // channel: top_hits
    contams             = COMBINE_MASH_REPORTS.out.contams              // channel: contams
    plasmids            = COMBINE_MASH_REPORTS.out.plasmids             // channel: plasmids

    stats_out           = STATS.out.stats_out                           // channel: [ stats_report ]

    cov                 = COVERAGE.out.cov                              // channel: [ val(sample_name), coverage ]

    versions            = ch_versions                                   // channel: [ versions.yml ]
}