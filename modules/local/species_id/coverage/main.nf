process COVERAGE {
    label 'process_single'

    container "https://depot.galaxyproject.org/singularity/centos:7.9.2009"

    input:
    path(stat_out)
    val(prefix)

    output:
    path "*coverage.tsv", emit: cov
    path 'versions.yml', emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """

    header=( "ID" "%target>10x" )
    echo \${header[@]} | sed 's/ /\t/g' > ${prefix}_coverage.tsv

    for sample in $stat_out; do
        sample_id=\$(basename \${sample%%_stats.*})
        grep "percentage of target genome with coverage > 10 (%):" \${sample} | awk -v s=\$sample_id 'BEGIN{ OFS="\t" }{ print s,\$10 }' >> ${prefix}_coverage.tsv
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Awk: \$(awk --version 2>&1 | sed -n 1p | sed 's/GNU Awk //')
    END_VERSIONS

    """

}
