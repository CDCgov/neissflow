process MASH {
    tag "$meta.id"
    label 'process_medium'

    container 'https://depot.galaxyproject.org/singularity/mash:2.3--he348c14_1'

    input:
    tuple val(meta), file(reads)
    path(mash_db)

    output:
    path '*.tsv'       , emit: mash_results
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
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

    mash screen -w -p ${task.cpus} $mash_db intermediate.fastq > "${prefix}.tsv"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mash: \$( mash --version )
    END_VERSIONS
    """
}