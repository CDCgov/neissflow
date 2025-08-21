process REROOT {
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gotree%3A0.4.5--h9ee0642_0' :
        'quay.io/biocontainers/gotree:0.4.5--h9ee0642_0' }"

    input:
    path(best_tree)

    output:
    path 'midpoint_bestTree.nw'  , emit: midpoint
    path "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    gotree reroot midpoint -i $best_tree > midpoint_bestTree.nw

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Gotree: \$(gotree version 2>&1)
    END_VERSIONS

    """
}