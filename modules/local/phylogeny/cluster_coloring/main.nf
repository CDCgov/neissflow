process CLUSTER_COLORING {
    label 'process_single'

    container "https://depot.galaxyproject.org/singularity/centos:7.9.2009"

    input:
    path(clusters)

    output:
    path 'cluster_annotation.tsv', emit: annotation
    path 'versions.yml'          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    
    num_clusters=\$(wc -l $clusters | awk 'BEGIN{ FS=" " }{ print \$1 }')

    val=( A B C D E F 0 1 2 3 4 5 6 7 8 9 )
    colors=""
    for cluster in \$(seq 1 \$num_clusters); do
        hex="#"
        for i in {1..6}; do
            random_element=\$(printf "%s\n" "\${val[@]}" | shuf -n 1)
            hex+=\${random_element}
        done
        colors+=\$hex"-"
    done

    awk -vFS=" " -vOFS="\t" -v colorstr=\$colors \\
        'BEGIN{
            split(colorstr, colors, "-")
        }{ 
            for (i=1;i<=NF;i++){ 
                if( \$i !~ /^\\[/ && \$i !~ /\\]\$/ && \$i ~ /^[^0-9]/ ){
                    print \$i,colors[NR] 
                } 
            }  
        }' $clusters \\
        > cluster_annotation.tsv
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Awk: \$(awk --version 2>&1 | sed -n 1p | sed 's/GNU Awk //')
    END_VERSIONS
    
    """
}