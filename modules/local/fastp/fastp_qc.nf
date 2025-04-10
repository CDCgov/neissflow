process FASTP_QC_CHECK {
    label 'process_low'

    container "https://depot.galaxyproject.org/singularity/centos:7.9.2009"

    input:
    path fastp_report
    val(prefix)

    output:
    path '*passed_qc1.tsv', emit: passed
    path '*failed_qc1.tsv', emit: failed 
    path "versions.yml"  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    head -n 1 $fastp_report > ${prefix}_passed_qc1.tsv
    head -n 1 $fastp_report > ${prefix}_failed_qc1.tsv

    tail -n +2 $fastp_report | awk -v prefix=${prefix} 'BEGIN{ OFS="\t" }{ if( \$2 < 352000 || \$11 < 88000 || \$12 < 22418200 ){ print >> prefix"_failed_qc1.tsv" } else { print >> prefix"_passed_qc1.tsv" } }'

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version 2>&1 | sed 's/GNU bash, version //; s/(.*//' | awk 'NR==1{ print \$0 }')
    END_VERSIONS
    """
}