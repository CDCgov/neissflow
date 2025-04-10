process ASSEMBLY_STATS {
    label 'process_low'

    container "docker://biopython/biopython:latest"

    input:
    path(all_assemblies)
    val(prefix)

    output:
    path "*Denovo_assembly_Stats_QC_report.txt", emit: qc_stats_report
    path  "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    Denovo_Assembly_QC.py -so "${prefix}_Denovo_assembly_Stats_QC_report.txt" -e .fa $all_assemblies

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Python: \$(python --version 2>&1 | sed 's/Python //;')
    END_VERSIONS
    """
}
