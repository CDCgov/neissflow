process RAXML {
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/raxml%3A8.2.9--hec16e2b_6' :
        'quay.io/biocontainers/raxml:8.2.9--hec16e2b_6' }"
    

    input:
    path(phylip)
    path(partition_guide)

    output:
    //path '*', emit: all
    path 'RAxML_bipartitions.*'            , emit: bipart
    path 'RAxML_bipartitionsBranchLabels.*', emit: bibranch
    path 'RAxML_bootstrap.*'               , emit: bootstrap          
    path 'RAxML_bestTree.*'                , emit: best_tree
    path 'RAxML_info.*'                    , emit: info
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    file=$phylip
    name=\${file%%.filtered_polymorphic_sites.phylip}
    raxmlHPC-PTHREADS -s $phylip -n \$name --asc-corr=stamatakis -q $partition_guide -m GTRGAMMAX -T ${task.cpus} -N autoMRE -p \$RANDOM -f a -x \$RANDOM 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        raxmlHPC-PTHREADS: \$(echo \$(raxmlHPC-PTHREADS -v 2>&1) | sed 's/^.*version //; s/ released.*\$//')
    END_VERSIONS

    """
}