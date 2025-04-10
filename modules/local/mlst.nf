nextflow.enable.dsl=2

process MLST {
    tag "$sample_name"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://depot.galaxyproject.org/singularity/mlst:2.23.0--hdfd78af_0' :
    'biocontainers/mlst:2.23.0--hdfd78af_0' }"

    input:
    tuple val(sample_name), path(assembly)

    output:
    tuple val(sample_name), path("${sample_name}/${sample_name}_mlst.tsv"), emit: mlst_report
    path "versions.yml"                                                  , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    """

    if [ ! -d ${sample_name} ]; then
        mkdir ${sample_name}
    fi

    header=("Sample" "ST")
    echo \${header[@]} | sed 's/ /\t/g' > ${sample_name}/${sample_name}_mlst.tsv

    mlst --threads ${task.cpus} --scheme neisseria $assembly --label ${sample_name} --datadir ${params.pubmlst} --blastdb ${params.blastdb} | cut -f1,3 >> ${sample_name}/${sample_name}_mlst.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mlst: \$( echo \$(mlst --version 2>&1) | sed 's/mlst //' )
    END_VERSIONS

    """
}