process MLST {
    tag "$meta.id"
    label 'process_low'

    container "https://depot.galaxyproject.org/singularity/mlst%3A2.23.0--hdfd78af_0"

    input:
    tuple val(meta), path(assembly)
    path pubmlst
    path blastdb
    val dbname

    output:
    tuple val(meta), path("*/*_mlst.tsv"), emit: mlst_report
    path "versions.yml"                  , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args   ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
    """

    if [ ! -d ${prefix} ]; then
        mkdir ${prefix}
    fi
    
    header=("Sample" "ST")
    echo \${header[@]} | sed 's/ /\t/g' > ${prefix}/${prefix}_mlst.tsv

    mlst \\
        --threads ${task.cpus} \\
        $args \\
        $assembly \\
        --label ${prefix} \\
        --datadir $pubmlst \\
        --blastdb ${blastdb}/${dbname} | cut -f1,3 >> ${prefix}/${prefix}_mlst.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mlst: \$( echo \$(mlst --version 2>&1) | sed 's/mlst //' )
    END_VERSIONS

    """
}