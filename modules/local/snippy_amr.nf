nextflow.enable.dsl=2

process SNIPPY_AMR {
    tag "$sample_name"
    label 'process_medium'

    container "https://depot.galaxyproject.org/singularity/snippy%3A4.6.0--0"
    
    input:
    tuple val(sample_name), path(fastq_paths)
    path amr_ref

    output:
    tuple val(sample_name), path("*/*.tab")              , emit: tab
    tuple val(sample_name), path("*/*.csv")              , emit: csv
    tuple val(sample_name), path("*/*.html")             , emit: html
    tuple val(sample_name), path("*/*.vcf")              , emit: vcf
    tuple val(sample_name), path("*/*.bed")              , emit: bed
    tuple val(sample_name), path("*/*.gff")              , emit: gff
    tuple val(sample_name), path("*/*.bam")              , emit: bam
    tuple val(sample_name), path("*/*.bam.bai")          , emit: bai
    tuple val(sample_name), path("*/*.aligned.fa")       , emit: aligned_fa
    tuple val(sample_name), path("*/*.consensus.fa")     , emit: consensus_fa
    tuple val(sample_name), path("*/*.consensus.subs.fa"), emit: consensus_subs_fa
    tuple val(sample_name), path("*/*.raw.vcf")          , emit: raw_vcf
    tuple val(sample_name), path("*/*.filt.vcf")         , emit: filt_vcf
    tuple val(sample_name), path("*/*.vcf.gz")           , emit: vcf_gz
    tuple val(sample_name), path("*/*.vcf.gz.csi")       , emit: vcf_csi
    tuple val(sample_name), path("*/*.txt")              , emit: txt
    path "versions.yml"                                  , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    read_1 = fastq_paths[0]
    read_2 = fastq_paths[1]
    """

    snippy --cpus ${task.cpus} --prefix ${sample_name}_AMR --outdir $sample_name --ref $amr_ref --R1 $read_1 --R2 $read_2 --minfrac 0.9 --basequal 20

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snippy: \$(echo \$(snippy --version 2>&1) | sed 's/snippy //')
    END_VERSIONS

    """
}
