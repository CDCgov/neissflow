process STATS {
    tag "$sample_name"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.20--h50ea8bc_0' :
        'quay.io/biocontainers/samtools:1.20--h50ea8bc_0' }"

    input:
    tuple val(sample_name), path(bam), path(bai)

    output:
    path "*.txt", emit: stats_out
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when
    
    script: 
    """

    samtools \\
        stats \\
        -g 10 \\
        --threads ${task.cpus} \\
        $bam \\
        CP012026 \\
        | grep ^SN \\
        | cut -f 2- \\
        > ${sample_name}_stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}

