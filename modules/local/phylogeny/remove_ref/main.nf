process REMOVE_REF {
    label 'process_low_memory'

    container "https://depot.galaxyproject.org/singularity/centos:7.9.2009"

    input:
    path(clean_full_aln)

    output:
    path 'core_no_ref.clean.full.aln', emit: no_ref_aln
    path 'versions.yml'              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """

    sed -n '/>Reference/q;p' $clean_full_aln > core_no_ref.clean.full.aln

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sed: \$(sed --version 2>&1 | sed -n 1p | sed 's/sed (GNU sed) //')
    END_VERSIONS

    """

}