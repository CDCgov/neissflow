process FASTP {
    tag "$meta.id"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastp%3A0.23.4--hadf994f_2' :
        'quay.io/biocontainers/fastp:0.23.4--hadf994f_2' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*/*.gz'), emit: fastq_4_processing_files
    tuple val(meta), path('*.json'), emit: json_path
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args   ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
    read_1   = reads[0]
    read_2   = reads[1]
    """
    mkdir "$prefix"

    fastp \\
        -i $read_1 \\
        -I $read_2 \\
        -o "${prefix}/$read_1" \\
        -O "${prefix}/$read_2" \\
        -h "${prefix}.html" \\
        -j "${prefix}.json" \\
        -w ${task.cpus} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
    END_VERSIONS
    """
}
