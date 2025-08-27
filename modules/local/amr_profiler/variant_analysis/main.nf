process VARIANT_ANALYSIS {
    tag "$meta.id"
    label 'process_low'

    container "docker://python:3.9"

    input:
    tuple val(meta), path(wg), path(hgt), path(avg_depth), path(depths)
    path default_amr
    path columns
    path strands

    output:
    tuple val(meta), path("*/*_variant_report.tsv"), emit: report
    tuple val(meta), path ("*/*_amr_vcf.tsv")      , emit: amr_vcf
    path "versions.yml"                            , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    prefix   = task.ext.prefix ?: "${meta.id}"
    """

    AMR_variant_analysis.py \\
        -w $wg \\
        -t $hgt \\
        -c $avg_depth \\
        -n $prefix \\
        -o $prefix \\
        -d $default_amr \\
        -f $columns \\
        -s $depths \\
        -gs $strands

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Python: \$(python --version 2>&1 | sed 's/Python //;')
    END_VERSIONS

    """
}