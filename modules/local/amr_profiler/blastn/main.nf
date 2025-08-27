process BLASTN {
    tag "$meta.id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/blast:2.15.0--pl5321h6f7f691_1':
        'biocontainers/blast:2.15.0--pl5321h6f7f691_1' }"

    input:
    tuple val(meta), path(assembly)
    path blastdb
    val penAdb
    val porBdb
    path mtrR_mosaic_ref

    output:
    tuple val(meta), path("*/*_amr_blast.tsv"), emit: blast_report
    path "versions.yml"                       , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    prefix   = task.ext.prefix ?: "${meta.id}"
    """

    get_allele () {
        awk 'NR==1 { n=split(\$2,allele,"_"); print allele[n] }' \$1
    }

    if [ ! -d ${prefix} ]; then
        mkdir ${prefix}
    fi

    makeblastdb -in $assembly -dbtype 'nucl' -out ${prefix}/blastdb/${prefix}db

    blastn -num_threads ${task.cpus} -query $assembly -db ${blastdb}/${penAdb} -out "${prefix}/${prefix}_penA.tsv" -outfmt=6
    blastn -num_threads ${task.cpus} -query $assembly -db ${blastdb}/${porBdb} -out "${prefix}/${prefix}_porB.tsv" -outfmt=6
    blastn -num_threads ${task.cpus} -query $assembly -subject $mtrR_mosaic_ref -out "${prefix}/${prefix}_mtrR_mosaic.tsv" -outfmt=6

    declare -A amr_blast

    amr_blast['penA allele']=\$(get_allele "${prefix}/${prefix}_penA.tsv")
    amr_blast['porB allele']=\$(get_allele "${prefix}/${prefix}_porB.tsv")

    amr_blast['mtrR_mosaic']=\$(awk 'NR==1 { if( \$3 >= 98.0 ){ print "True" }else{ print "False" } }' "${prefix}/${prefix}_mtrR_mosaic.tsv") #98% match threshold determined by Matthew

    printf "%s\t" "Sample" > ${prefix}/${prefix}_amr_blast.tsv
    declare -i count
    count=1
    for gene in "\${!amr_blast[@]}"; do
        if (( count < \${#amr_blast[@]} )); then
            printf "%s\t" "\$gene" >> ${prefix}/${prefix}_amr_blast.tsv
        else
            printf "%s\n" "\$gene" >> ${prefix}/${prefix}_amr_blast.tsv
        fi
        count+=1
    done

    printf "%s\t" "${prefix}" >> ${prefix}/${prefix}_amr_blast.tsv
    count=1
    for gene in "\${!amr_blast[@]}"; do
        if (( count < \${#amr_blast[@]} )); then
            printf "%s\t" "\${amr_blast[\$gene]}" >> ${prefix}/${prefix}_amr_blast.tsv
        else
            printf "%s\n" "\${amr_blast[\$gene]}" >> ${prefix}/${prefix}_amr_blast.tsv
        fi
        count+=1
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        blastn: \$(echo \$(blastn -version 2>&1) | sed 's/^.*blastn: //; s/ .*\$//' | sed 's/+//' | tr -d '\n')
    END_VERSIONS

    """
}