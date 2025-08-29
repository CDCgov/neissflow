process SHOVILL {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/shovill:1.1.0--0' :
        'biocontainers/shovill:1.1.0--0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_contigs.fa")                       , emit: contigs
    tuple val(meta), path("shovill.corrections")                , emit: corrections
    tuple val(meta), path("shovill.log")                        , emit: log
    tuple val(meta), path("{skesa,spades,megahit,velvet}.fasta"), emit: raw_contigs
    tuple val(meta), path("contigs.{fastg,gfa,LastGraph}")      , optional:true, emit: gfa
    path "versions.yml"                                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix     = task.ext.prefix ?: "${meta.id}"
    def args   = task.ext.args ?: ''
    def memory = task.memory.toGiga()

    if (params.downsample) {
        """
        shovill \\
            --R1 ${reads[0]} \\
            --R2 ${reads[1]} \\
            --tmpdir \$TMPDIR \\
            --cpus ${task.cpus} \\
            --ram $memory \\
            --outdir ./ \\
            --depth ${params.depth} \\
            $args \\
            --force

        mv contigs.fa ${prefix}_contigs.fa

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            shovill: \$(echo \$(shovill --version 2>&1) | sed 's/^.*shovill //')
        END_VERSIONS
        """
    } else {
        """
        shovill \\
            --R1 ${reads[0]} \\
            --R2 ${reads[1]} \\
            --tmpdir \$TMPDIR \\
            --cpus ${task.cpus} \\
            --ram $memory \\
            --outdir ./ \\
            $args \\
            --force

        mv contigs.fa ${prefix}_contigs.fa

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            shovill: \$(echo \$(shovill --version 2>&1) | sed 's/^.*shovill //')
        END_VERSIONS
        """
    }
}
