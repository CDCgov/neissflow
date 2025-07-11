process OUTBREAK_DETECTION {
    label 'process_single'

    container "https://depot.galaxyproject.org/singularity/numpy%3A2.2.2"

    input:
    path(snp_matrix)
    val snp_dist

    output:
    path("isolate_clusters.txt"), emit: outbreaks
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: "-i ${snp_matrix} -d ${snp_dist}"

    """

    outbreak_detection.py \\
        $args > isolate_clusters.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Python: \$(python --version 2>&1 | sed 's/Python //;')
    END_VERSIONS

    """
}