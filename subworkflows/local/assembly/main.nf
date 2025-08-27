//
// shovill assembly & assembly QC
//

include { SHOVILL                } from '../../../modules/local/assembly/shovill/main'
include { ASSEMBLY_STATS         } from '../../../modules/local/assembly/assembly_stats/main'
include { QUAST                  } from '../../../modules/nf-core/quast/main'

workflow ASSEMBLY {
    take:
    reads             // channel: [ meta, [ reads ] ]
    ch_contigs        // channel: [ meta, contigs ]
    prefix            // val(prefix)

    main:

    ch_versions = Channel.empty()

    //
    // shovill assembly
    //
    ch_assembly = Channel.empty()
    if (params.only_fastq){
        SHOVILL (
            reads
        )
        ch_assembly = SHOVILL.out.contigs
        ch_versions = ch_versions.mix(SHOVILL.out.versions)
    } else {
        ch_assembly = ch_contigs
    }

    //
    // Get assembly metrics for QC 
    //
    ch_assemblies = ch_assembly
                    .map {
                        meta, contigs ->
                        contigs
                    }
    
    ch_qc_stats_report = Channel.empty()
    if (!params.skip_assembly_qc) {
        ASSEMBLY_STATS (
            ch_assemblies.collect(),
            prefix
        )
        ch_qc_stats_report = ASSEMBLY_STATS.out.qc_stats_report
        ch_versions = ch_versions.mix(ASSEMBLY_STATS.out.versions)
    }

    QUAST(
        ch_assembly,
        [[],"${params.FA19cg}"],
        [[],[]]
    )
    ch_versions = ch_versions.mix(QUAST.out.versions)

    emit:

    contigs             = ch_assembly                                // channel: [ meta, contigs ] 

    qc_stats_report     = ch_qc_stats_report                         // channel: qc_stats_report

    quast_results       = QUAST.out.results                          // channel: [ meta, results ]

    versions            = ch_versions                                // channel: [ versions.yml ]

}