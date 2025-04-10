//
// Phylogenetic analysis and tree generation
//

include { SNIPPY_CORE          } from '../../modules/local/snippy_core'
include { SNIPPY_CLEAN         } from '../../modules/local/snippy_clean'
include { REMOVE_REF           } from '../../modules/local/remove_ref'
include { SNPDISTS             } from '../../modules/local/snpdists'
include { OUTBREAK_DETECTION   } from '../../modules/local/outbreak_detection'
include { CLUSTER_COLORING     } from '../../modules/local/cluster_coloring'
include { GUBBINS              } from '../../modules/local/gubbins'
include { COUNT_MONO_NUC       } from '../../modules/local/count_mono'
include { MAKE_PARTITION_GUIDE } from '../../modules/local/make_guide'
include { RAXML                } from '../../modules/local/raxml'
include { PHYLOGENY_QC         } from '../../modules/local/phylogeny_qc'
include { REROOT               } from '../../modules/local/reroot'
include { GOTREE_PNG           } from '../../modules/local/gotree'
include { REPORT               } from '../../modules/local/report'

workflow PHYLOGENY {
    take:
    vcf            // channel: [ vcf ]
    aligned_fa     // channel: [ aligned_fa ]
    samples        // channel: [ sample ]

    main:

    ch_versions = Channel.empty()

    //
    // Align core SNPs
    //
    if (params.reference_genome){
        //Use difference reference genome if given
        SNIPPY_CORE (
            vcf,
            aligned_fa,
            params.reference_genome
            )
    } else {
        SNIPPY_CORE (
            vcf,
            aligned_fa,
            params.FA19_ref
            )
    }
    ch_versions = ch_versions.mix(SNIPPY_CORE.out.versions)

    //
    // Cleanup core SNP alignment 
    //
    ch_clean = Channel.empty()
    SNIPPY_CLEAN (
        SNIPPY_CORE.out.full_aln
    )
    ch_clean = SNIPPY_CLEAN.out.clean_full_aln
    ch_versions = ch_versions.mix(SNIPPY_CLEAN.out.versions)

    if (params.remove_ref){

        //
        // Remove reference from Snippy core alignment
        //
        REMOVE_REF (
            ch_clean
        )
        ch_clean = REMOVE_REF.out.no_ref_aln
        ch_versions = ch_versions.mix(REMOVE_REF.out.versions)
    }

    //
    // Mark recombination regions and contruct phylogeny on mutations outside of recombination regions
    //
    GUBBINS (
        ch_clean
    )
    ch_versions = ch_versions.mix(GUBBINS.out.versions)

    //
    // Get counts for each unambigious nucleotide from monomorphic sites
    //
    COUNT_MONO_NUC (
        ch_clean
    )
    //ch_versions = ch_versions.mix(COUNT_MONO_NUC.out.versions)

    //
    // Calculate SNP distances between samples
    //
    SNPDISTS (
        GUBBINS.out.fasta
    )
    ch_versions = ch_versions.mix(SNPDISTS.out.versions)

    //
    // Get potential outbreak clusters by identifying connected components in graph constructed using SNP distances
    //
    OUTBREAK_DETECTION (
        SNPDISTS.out.snp_matrix
    )
    ch_versions = ch_versions.mix(OUTBREAK_DETECTION.out.versions)

    //
    //Assign each outbreak cluster a hex color for tree annotation
    //
    CLUSTER_COLORING (
        OUTBREAK_DETECTION.out.outbreaks
    )
    //ch_versions = ch_versions.mix(CLUSTER_COLORING.out.versions)

    //
    // Make partition guide for RAxML ascertainment correction
    //
    MAKE_PARTITION_GUIDE (
        GUBBINS.out.phylip,
        COUNT_MONO_NUC.out.monomorphic_nuc_vals
    )
    ch_versions = ch_versions.mix(MAKE_PARTITION_GUIDE.out.versions)

    //
    // Phylogenetic analysis with RAxML (output Newick tree)
    //
    RAXML (
        GUBBINS.out.phylip,
        MAKE_PARTITION_GUIDE.out.partition_guide
    )
    ch_versions = ch_versions.mix(RAXML.out.versions)

    //
    // Midroot best tree with Gotree
    //
    REROOT (
        RAXML.out.best_tree
    )
    ch_versions = ch_versions.mix(REROOT.out.versions)

    //
    // Perform QC checks on core alignment and newick tree
    //
    PHYLOGENY_QC (
        SNIPPY_CORE.out.full_aln,
        REROOT.out.midpoint,
        samples,
        COUNT_MONO_NUC.out.monomorphic_nuc_vals
    )
    ch_versions = ch_versions.mix(PHYLOGENY_QC.out.versions)

    //
    // Generate PNG from newick formatted midrooted best tree
    //
    GOTREE_PNG (
        REROOT.out.midpoint,
        CLUSTER_COLORING.out.annotation
    )
    ch_versions = ch_versions.mix(GOTREE_PNG.out.versions)

    //
    // Generate HTML report with phylogenetic tree and potential outbreak clusters displayed
    //
    REPORT (
        GOTREE_PNG.out.png,
        OUTBREAK_DETECTION.out.outbreaks
    )
    ch_versions = ch_versions.mix(REPORT.out.versions)

    emit:

    full_aln             = SNIPPY_CORE.out.full_aln                // channel: [ full_aln ]
    txt                  = SNIPPY_CORE.out.txt                     // channel: [ txt ]
    clean_full_aln       = ch_clean                                // channel: [ clean_full_aln ]
    phylip               = GUBBINS.out.phylip                      // channel: [ phylip ]
    fasta                = GUBBINS.out.fasta                       // channel : [ fasta ]
    gff                  = GUBBINS.out.gff                         // channel : [ gff ]
    pred_embl            = GUBBINS.out.pred_embl                   // channel : [ pred_embl ]
    base_recon_embl      = GUBBINS.out.base_recon_embl             // channel : [ base_recon_embl ]
    vcf                  = GUBBINS.out.vcf                         // channel : [ vcf ]
    tre                  = GUBBINS.out.tre                         // channel : [ tre ]
    node_tre             = GUBBINS.out.node_tre                    // channel : [ node_tre ]
    //log                  = GUBBINS.out.log                         // channel : [ log ]
    csv                  = GUBBINS.out.csv                         // channel : [ csv ]
    monomorphic_nuc_vals = COUNT_MONO_NUC.out.monomorphic_nuc_vals // channel: [ monomorphic_nuc_vals ]
    snp_matrix           = SNPDISTS.out.snp_matrix                 // channel: [ snp_matrix ]
    outbreaks            = OUTBREAK_DETECTION.out.outbreaks        // channel: [ outbreaks ]
    best_tree            = RAXML.out.best_tree                     // channel: [ best_tree ]
    bipart               = RAXML.out.bipart                        // channel: [ bipart ]
    info                 = RAXML.out.info                          // channel: [ info ]
    bibranch             = RAXML.out.bibranch                      // channel: [ bibranch ]
    bootstrap            = RAXML.out.bootstrap                     // channel: [ bootstrap ]
    midpoint             = REROOT.out.midpoint                     // channel: [ midpoint ]
    qc_report            = PHYLOGENY_QC.out.qc_report              // channel: [ qc_report ]
    png                  = GOTREE_PNG.out.png                      // channel: [ png ]
    report               = REPORT.out.report                       // channel: [ report ]

    versions           = ch_versions                               // channel: [ versions.yml ]
}