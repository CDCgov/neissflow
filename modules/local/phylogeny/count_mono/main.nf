process COUNT_MONO_NUC {
    label 'process_medium_memory'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/datamash%3A1.8' :
        'quay.io/bioconda/base-glibc-busybox-bash:latest' }"

    input:
    path(clean_full_aln)

    output:
    path '*_partition_data.txt', emit: monomorphic_nuc_vals
    path "versions.yml"        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    file=$clean_full_aln
    name=\${file%%.clean.full.aln}

    awk -vRS=">" -vORS="\n" -vFS="\n" -vOFS="" 'NR>1 { \$1=\$1; for (i=2; i<NF; i++) printf \$i; print \$NF }' $clean_full_aln | awk  -vFS="" -vOFS=" " '{\$1=\$1; print \$0 }' > realign_fasta.txt 

    datamash -W transpose <realign_fasta.txt > transpose.txt

    awk -vFS=" " -vOFS=" " '
    {
        yes=0
        one=\$1
        for(i=2; i<=NF; i++) {
            if( one!=\$i ) {
                yes=1
            }
        }
        
        if( yes==0 ){
            dna[one]+=1
        }
    }
    END {
        print dna["A"],dna["C"],dna["G"],dna["T"]
    }' transpose.txt > \${name}_partition_data.txt


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        datamash: \$(datamash --version 2>&1 | sed -n 1p | sed 's/datamash (GNU datamash) //')
    END_VERSIONS

    """
}