process BLASTN {
    tag "$sample_name"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/blast:2.15.0--pl5321h6f7f691_1':
        'biocontainers/blast:2.15.0--pl5321h6f7f691_1' }"

    input:
    tuple val(sample_name), path(assembly)

    output:
    tuple val(sample_name), path("${sample_name}/${sample_name}_amr_blast.tsv"), emit: blast_report
    path "versions.yml"                                                       , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    """

    get_allele () {
        awk 'NR==1 { n=split(\$2,allele,"_"); print allele[n] }' \$1
    }

    if [ ! -d ${sample_name} ]; then
        mkdir ${sample_name}
    fi

    makeblastdb -in $assembly -dbtype 'nucl' -out ${sample_name}/blastdb/${sample_name}db

    blastn -num_threads ${task.cpus} -query $assembly -db $params.penAdb -out "${sample_name}/${sample_name}_penA.tsv" -outfmt=6
    blastn -num_threads ${task.cpus} -query $assembly -db $params.porBdb -out "${sample_name}/${sample_name}_porB.tsv" -outfmt=6
    blastn -num_threads ${task.cpus} -query $assembly -subject $params.mtrR_mosaic_ref -out "${sample_name}/${sample_name}_mtrR_mosaic.tsv" -outfmt=6

    declare -A amr_blast

    amr_blast['penA allele']=\$(get_allele "${sample_name}/${sample_name}_penA.tsv")
    amr_blast['porB allele']=\$(get_allele "${sample_name}/${sample_name}_porB.tsv")

    amr_blast['mtrR_mosaic']=\$(awk 'NR==1 { if( \$3 >= 98.0 ){ print "True" }else{ print "False" } }' "${sample_name}/${sample_name}_mtrR_mosaic.tsv") #98% match threshold determined by Matthew

    printf "%s\t" "Sample" > ${sample_name}/${sample_name}_amr_blast.tsv
    declare -i count
    count=1
    for gene in "\${!amr_blast[@]}"; do
        if (( count < \${#amr_blast[@]} )); then
            printf "%s\t" "\$gene" >> ${sample_name}/${sample_name}_amr_blast.tsv
        else
            printf "%s\n" "\$gene" >> ${sample_name}/${sample_name}_amr_blast.tsv
        fi
        count+=1
    done

    printf "%s\t" "${sample_name}" >> ${sample_name}/${sample_name}_amr_blast.tsv
    count=1
    for gene in "\${!amr_blast[@]}"; do
        if (( count < \${#amr_blast[@]} )); then
            printf "%s\t" "\${amr_blast[\$gene]}" >> ${sample_name}/${sample_name}_amr_blast.tsv
        else
            printf "%s\n" "\${amr_blast[\$gene]}" >> ${sample_name}/${sample_name}_amr_blast.tsv
        fi
        count+=1
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        blastn: \$(echo \$(blastn -version 2>&1) | sed 's/^.*blastn: //; s/ .*\$//' | sed 's/+//' | tr -d '\n')
    END_VERSIONS

    """
}