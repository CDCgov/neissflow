process REPORT {
    label 'process_single'

    container "https://depot.galaxyproject.org/singularity/centos:7.9.2009"
    
    input:
    path(png)
    path(isolate_clusters)

    output:
    path 'phylogeny_report.html', emit: report
    path 'versions.yml'         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """

    generate_html.sh -p $png -c $isolate_clusters

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(sed --version 2>&1 | sed -n 1p | sed 's/sed (GNU sed) //')
    END_VERSIONS

    """
}