process SNIPPY_CORE {
    label 'process_low_memory'

    container "https://depot.galaxyproject.org/singularity/snippy%3A4.6.0--0"

    input:
    path(vcf)
    path(aligned_fa)
    path(ref)

    output:
    path 'core.full.aln'          , emit: full_aln
    path '*.txt'                  , emit: txt
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # Collect samples into necessary folders
    
    mkdir samples

    for file in $vcf; do
        sample_name=\${file%%.*}
        if [ ! -d samples/\$sample_name ]; then
            mkdir samples/\$sample_name
        fi
        ln \$file samples/\${sample_name}/
    done

    for file in $aligned_fa; do
        sample_name=\${file%%.*}
        ln \$file samples/\${sample_name}/
    done

    snippy-core --ref $ref samples/*

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snippy-core: \$(echo \$(snippy-core --version 2>&1) | sed 's/snippy-core //')
    END_VERSIONS

    """
}