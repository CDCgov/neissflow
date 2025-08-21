process COMBINE_FASTP_REPORTS {
    label 'process_low'

    container "https://depot.galaxyproject.org/singularity/centos:7.9.2009"

    input:
    path(tsv_paths)
    val(prefix)

    output:
    path '*FASTQ_QC_report.tsv', emit: fastp_report
    path "versions.yml"       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    awk 'FNR==1 && NR!=1{next;}{print}' $tsv_paths > '${prefix}_FASTQ_QC_report.tsv'

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Awk: \$(awk --version 2>&1 | sed -n 1p | sed 's/GNU Awk //')
    END_VERSIONS
    """
}