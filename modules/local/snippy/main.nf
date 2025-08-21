process SNIPPY {
    tag "$meta.id"
    label 'process_medium'

    container "https://depot.galaxyproject.org/singularity/snippy%3A4.6.0--0"
    
    input:
    tuple val(meta), file(input)
    path(ref)

    output:
    tuple val(meta), path("*/*/*.tab")              , emit: tab
    tuple val(meta), path("*/*/*.csv")              , emit: csv
    tuple val(meta), path("*/*/*.html")             , emit: html
    tuple val(meta), path("*/*/*.vcf")              , emit: vcf
    tuple val(meta), path("*/*/*.bed")              , emit: bed
    tuple val(meta), path("*/*/*.gff")              , emit: gff
    tuple val(meta), path("*/*/*.bam")              , emit: bam
    tuple val(meta), path("*/*/*.bam.bai")          , emit: bai
    tuple val(meta), path("*/*/*.log")              , emit: log
    tuple val(meta), path("*/*/*.aligned.fa")       , emit: aligned_fa
    tuple val(meta), path("*/*/*.consensus.fa")     , emit: consensus_fa
    tuple val(meta), path("*/*/*.consensus.subs.fa"), emit: consensus_subs_fa
    tuple val(meta), path("*/*/*.raw.vcf")          , emit: raw_vcf
    tuple val(meta), path("*/*/*.filt.vcf")         , emit: filt_vcf
    tuple val(meta), path("*/*/*.vcf.gz")           , emit: vcf_gz
    tuple val(meta), path("*/*/*.vcf.gz.csi")       , emit: vcf_csi
    tuple val(meta), path("*/*/*.txt")              , emit: txt
    path "versions.yml"                             , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args   ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
    if (input.size() == 2) {
        read_1 = input[0]
        read_2 = input[1]
        """

        filename=$ref
        outdir="\${filename%.*}"

        snippy \\
            --cpus ${task.cpus} \\
            --prefix $prefix \\
            --outdir \${outdir}/$prefix \\
            --ref $ref \\
            --R1 $read_1 \\
            --R2 $read_2 \\
            --tmpdir \$TMPDIR \\
            $args

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            snippy: \$(echo \$(snippy --version 2>&1) | sed 's/snippy //')
        END_VERSIONS

        """
    } else {
        """

        filename=$ref
        outdir="\${filename%.*}"

        snippy \\
            --cpus ${task.cpus} \\
            --prefix $prefix \\
            --outdir \${outdir}/$prefix \\
            --ref $ref \\
            --contigs $input

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            snippy: \$(echo \$(snippy --version 2>&1) | sed 's/snippy //')
        END_VERSIONS

        """

    }
}
