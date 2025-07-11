process SNIPPY_CLEAN {
    label 'process_low_memory'

    container "https://depot.galaxyproject.org/singularity/snippy%3A4.6.0--0"

    input:
    path(full_aln)

    output:
    path '*.clean.full.aln', emit: clean_full_aln
    path "versions.yml"    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    snippy-clean_full_aln $full_aln > core.clean.full.aln

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snippy-clean_full_aln: \$(echo \$(snippy-clean_full_aln --version 2>&1) | sed 's/snippy-clean_full_aln //')
    END_VERSIONS

    """
}