process RAXMLNG {
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/raxml-ng:1.2.2--h6747034_1' :
        'biocontainers/raxml-ng:1.2.2--h6747034_1' }"

    input:
    path(alignment)
    path(mono_sites)
    val model

    output:
    path("*.bestModel")         , emit: bestModel
    path("*.bestTree")          , emit: bestTree
    path("*.bootstraps")        , emit: bootstraps
    path("*.raxml.log")         , emit: log
    path("*.mlTrees")           , emit: mlTrees
    path("*.rba")               , emit: rba
    path("*.startTree")         , emit: startTree
    path("*.support")           , emit: support
    path("*.bestTreeCollapsed") , optional: true , emit: bestTreeCollapsed
    path "versions.yml"         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    // fix random seed for reproducibility if not specified in command line
    if (!(args ==~ /.*--seed.*/)) {args += " --seed 42"}
    """
    partitions=\$(cat $mono_sites)
    raxml-ng \\
        $args \\
        --msa $alignment \\
        --model ${model}"{\$partitions}" \\
        --threads $task.cpus \\
        --prefix "raxmlng"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        raxmlng: \$(echo \$(raxml-ng --version 2>&1) | sed 's/^.*RAxML-NG v. //; s/released.*\$//')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def touch_files = args.contains('--bootstrap') || args.contains('--bs-trees') ? "touch ${prefix}.raxml.bootstraps" : "touch ${prefix}.raxml.bestTree"
    """
    # Create stub output files
    ${touch_files}

    # Create versions.yml
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        raxmlng: \$(echo \$(raxml-ng --version 2>&1) | sed 's/^.*RAxML-NG v. //; s/released.*\$//')
    END_VERSIONS
    """
}
