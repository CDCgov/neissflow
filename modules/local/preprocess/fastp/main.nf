process FASTP {
    tag "$sample_name"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastp%3A0.23.4--hadf994f_2' :
        'quay.io/biocontainers/fastp:0.23.4--hadf994f_2' }"

    input:
    tuple val(sample_name), path(reads)

    output:
    tuple val(sample_name), path('*/*.gz'), emit: fastq_4_processing_files
    tuple val(sample_name), path('*.json'), emit: json_path
    path "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    read_1 = reads[0]
    read_2 = reads[1]
    """
    mkdir "$sample_name"

    #out_1_name=\$(basename $read_1)
    #out_2_name=\$(basename $read_2)

    fastp -i $read_1 -I $read_2 -o "${sample_name}/$read_1" -O "${sample_name}/$read_2" --detect_adapter_for_pe -q 30 -l 100 -h "${sample_name}.html" -j "${sample_name}.json" -w ${task.cpus}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
    END_VERSIONS
    """
}
