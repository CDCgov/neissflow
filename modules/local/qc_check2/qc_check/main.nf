process QC_CHECK {
    label 'process_single' 

    container "https://depot.galaxyproject.org/singularity/centos:7.9.2009"

    input:
    path metrics
    val(prefix)

    output:
    path '*passed_qc2.tsv', emit: passed
    path '*failed_qc2.tsv', emit: failed
    path "versions.yml"  , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """

    head -n 1 $metrics > ${prefix}_passed_qc2.tsv
    head -n 1 $metrics > ${prefix}_failed_qc2.tsv

    tail -n +2 $metrics | awk -v prefix=${prefix} 'BEGIN{ OFS="\t" }{ if(  (\$7 !~ /Neisseria_gonorrhoeae/ && \$2 < 85) || \$2 < 85 || \$10 > 2500000 || \$19 < 11 || ( \$11 < 1850000 && \$10 < 2100000  ) || ( \$19 < 15 && \$14 < 0.25 ) || \$14 < 0.10 ){ print >> prefix"_failed_qc2.tsv" } else { print >> prefix"_passed_qc2.tsv" } }'
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Awk: \$(awk --version 2>&1 | sed -n 1p | sed 's/GNU Awk //')
    END_VERSIONS
    
    """
}