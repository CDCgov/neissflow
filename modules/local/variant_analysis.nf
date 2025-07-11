nextflow.enable.dsl=2

process VARIANT_ANALYSIS {
    tag "$sample_name"
    label 'process_low'

    container "docker://python:3.9"

    input:
    tuple val(sample_name), path(wg), path(hgt), path(avg_depth), path(depths)
    path default_amr
    path columns

    output:
    tuple val(sample_name), path("${sample_name}/${sample_name}_variant_report.tsv"), emit: report
    tuple val(sample_name), path ("${sample_name}/${sample_name}_amr_vcf.tsv")      , emit: amr_vcf
    path "versions.yml"                                                             , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    """

    AMR_variant_analysis.py -w $wg -t $hgt -c $avg_depth -n $sample_name -o $sample_name -d $default_amr -f $columns -s $depths

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Python: \$(python --version 2>&1 | sed 's/Python //;')
    END_VERSIONS

    """
}