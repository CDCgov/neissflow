process DEPTH {
    tag "$meta.id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.20--h50ea8bc_0' :
        'quay.io/biocontainers/samtools:1.20--h50ea8bc_0' }"
    
    input:
    tuple val(meta), path(wg_bam), path(hgt_bam), path(wg_bai), path(hgt_bai)
    path loci

    output:
    tuple val(meta), path("*/*_amr_depth.tsv"), emit: avg_depth
    tuple val(meta), path("*/*_depth.txt")    , emit: pos_depths
    path "versions.yml"                       , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    prefix   = task.ext.prefix ?: "${meta.id}"
    """

    if [ ! -d ${prefix} ]; then
        mkdir ${prefix}
    fi

    declare -A amr_genes 

    while read -r r g; do
        gene=\${g//[\$'\t\r\n ']}
        region=\${r//[\$'\t\r\n ']}
        samtools depth $wg_bam -r \$region -X $wg_bai > ${prefix}/\${gene}_depth.txt
        amr_genes[\$gene]=\$(awk '{ cov_sum+=\$3 }END{ print cov_sum/NR }' ${prefix}/\${gene}_depth.txt)
    done < $loci

    declare -A chroms
    chroms=(["X67293"]='23SrRNA' ["AB551787"]='blaTEM' ["EU048317"]='ermB' ["AE002098"]='ermC' ["NG_047825"]='ermF' ["16S-CP012026"]='FA19_16SrRNA' ["AY319932"]='mefA' ["NC_003112"]='Nm_sodC' ["AF116348"]='TetM-partial' )

    for i in "\${!chroms[@]}"; do
        amr_genes[\${chroms[\$i]}]=\$(samtools depth -r \$i $hgt_bam -X $hgt_bai | awk '{ cov_sum+=\$3 }END{ if( cov_sum > 0 ){ print cov_sum/NR }else{ print 0 } }')
    done


    printf "%s\t" "Sample" > ${prefix}/${prefix}_amr_depth.tsv
    declare -i count
    count=1
    for gene in "\${!amr_genes[@]}"; do
        if (( count < \${#amr_genes[@]} )); then
            printf "%s\t" "\$gene" >> ${prefix}/${prefix}_amr_depth.tsv
        else
            printf "%s\n" "\$gene" >> ${prefix}/${prefix}_amr_depth.tsv
        fi
        count+=1
    done

    printf "%s\t" "${prefix}" >> ${prefix}/${prefix}_amr_depth.tsv
    count=1
    for gene in "\${!amr_genes[@]}"; do
        if (( count < \${#amr_genes[@]} )); then
            printf "%s\t" "\${amr_genes[\$gene]}" >> ${prefix}/${prefix}_amr_depth.tsv
        else
            printf "%s\n" "\${amr_genes[\$gene]}" >> ${prefix}/${prefix}_amr_depth.tsv
        fi
        count+=1
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS

    """
}