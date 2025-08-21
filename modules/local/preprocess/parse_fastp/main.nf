process PARSE_FASTP_REPORTS {
    tag "$meta"
    label 'process_low'

    container "https://depot.galaxyproject.org/singularity/python%3A3.7"

    input:
    tuple val(meta), path(json_file)

    output:
    path("*.tsv")       , emit: tsv_path
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args   ?: ''
    """

    parse_filter.py \\
        -i $json_file \\
        -o ./

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Python: \$(python --version 2>&1 | sed 's/Python //;')
    END_VERSIONS

    """
}