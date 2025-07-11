process SNIPPY {
    tag "$sample_name"
    label 'process_medium'

    container "https://depot.galaxyproject.org/singularity/snippy%3A4.6.0--0"
    
    input:
    tuple val(sample_name), file(input)
    path(ref)

    output:
    tuple val(sample_name), path("*/*/*.tab")              , emit: tab
    tuple val(sample_name), path("*/*/*.csv")              , emit: csv
    tuple val(sample_name), path("*/*/*.html")             , emit: html
    tuple val(sample_name), path("*/*/*.vcf")              , emit: vcf
    tuple val(sample_name), path("*/*/*.bed")              , emit: bed
    tuple val(sample_name), path("*/*/*.gff")              , emit: gff
    tuple val(sample_name), path("*/*/*.bam")              , emit: bam
    tuple val(sample_name), path("*/*/*.bam.bai")          , emit: bai
    tuple val(sample_name), path("*/*/*.log")              , emit: log
    tuple val(sample_name), path("*/*/*.aligned.fa")       , emit: aligned_fa
    tuple val(sample_name), path("*/*/*.consensus.fa")     , emit: consensus_fa
    tuple val(sample_name), path("*/*/*.consensus.subs.fa"), emit: consensus_subs_fa
    tuple val(sample_name), path("*/*/*.raw.vcf")          , emit: raw_vcf
    tuple val(sample_name), path("*/*/*.filt.vcf")         , emit: filt_vcf
    tuple val(sample_name), path("*/*/*.vcf.gz")           , emit: vcf_gz
    tuple val(sample_name), path("*/*/*.vcf.gz.csi")       , emit: vcf_csi
    tuple val(sample_name), path("*/*/*.txt")              , emit: txt
    path "versions.yml"                                  , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    if (input.size() == 2) {
        read_1 = input[0]
        read_2 = input[1]
        """

        filename=$ref
        outdir="\${filename%.*}"

        snippy --cpus ${task.cpus} --prefix $sample_name --outdir \${outdir}/$sample_name --ref $ref --R1 $read_1 --R2 $read_2 --tmpdir \$TMPDIR --minfrac 0.9 --basequal 20

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            snippy: \$(echo \$(snippy --version 2>&1) | sed 's/snippy //')
        END_VERSIONS

        """
    } else {
        """

        filename=$ref
        outdir="\${filename%.*}"

        snippy --cpus ${task.cpus} --prefix $sample_name --outdir \${outdir}/$sample_name --ref $ref --contigs $input

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            snippy: \$(echo \$(snippy --version 2>&1) | sed 's/snippy //')
        END_VERSIONS

        """

    }
}
