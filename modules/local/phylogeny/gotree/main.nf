 process GOTREE_PNG {
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gotree%3A0.4.5--h9ee0642_0' :
        'quay.io/biocontainers/gotree:0.4.5--h9ee0642_0' }"

    input:
    path(rerooted)
    path(annotation)

    output:
    path 'bestTree.png'          , emit: png
    path "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    cat $rerooted | gotree draw png --fill-background -H 6000 -w 3000 --annotation-file $annotation -o bestTree.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Gotree: \$(gotree version 2>&1)
    END_VERSIONS

    """
}