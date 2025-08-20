process MERGE_AMR {
    label 'process_single'

    container "https://depot.galaxyproject.org/singularity/centos:7.9.2009"

    input:
    path(amr_reports)
    path(depth_reports)
    val(prefix)

    output:
    path '*amr_report.tsv'      , emit: all_amr
    path '*avg_depth_report.tsv', emit: all_depth
    path 'versions.yml'        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    declare -i count
    count=1
    for file in $amr_reports; do
        if (( count == 1 )); then
            awk 'NR==1 { print \$0 }' \$file > '${prefix}_amr_report.tsv'
        fi
        awk 'NR==2 { print \$0 }' \$file >> '${prefix}_amr_report.tsv'
        count+=1
    done

    count=1
    for file in $depth_reports; do
        if (( count == 1 )); then
            awk 'NR==1 { print \$0 }' \$file > '${prefix}_avg_depth_report.tsv'
        fi
        awk 'NR==2 { print \$0 }' \$file >> '${prefix}_avg_depth_report.tsv'
        count+=1
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Awk: \$(awk --version 2>&1 | sed -n 1p | sed 's/GNU Awk //')
    END_VERSIONS

    """
}