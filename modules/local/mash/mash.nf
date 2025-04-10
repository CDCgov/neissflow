process MASH {
    tag "$sample_name"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mash:2.3--he348c14_1':
        'biocontainers/mash:2.3--he348c14_1' }"

    input:
    tuple val(sample_name), file(reads)

    output:
    path '*.tsv'       , emit: mash_results
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    read_1 = reads[0]
    read_2 = reads[1]
    """

    isgzip=\$(\$(gzip -t $read_1 2>/dev/null); echo \$?)

    if (( \$isgzip == 0 )); then
        cmd=zcat
    else
        cmd=cat
    fi

    \$cmd $read_1 $read_2 2>/dev/null > intermediate.fastq

    mash screen -w -p ${task.cpus} $params.mash_db intermediate.fastq > "${sample_name}.tsv"

    rm intermediate.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mash: \$( mash --version )
    END_VERSIONS
    """
}