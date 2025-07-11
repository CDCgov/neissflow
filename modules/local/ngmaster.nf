nextflow.enable.dsl=2

process NGMASTER {
    tag "$sample_name"
    label 'process_low'

    container "docker://staphb/ngmaster:1.0.0"

    input:
    tuple val(sample_name), path(assembly)
    path ngmasterdb
    path ngstar
    path ngmast

    output:
    tuple val(sample_name), path("${sample_name}/${sample_name}_ngmaster.tsv"), emit: ngmaster_report
    path "versions.yml"                                                       , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    """

    if [ ! -d ${sample_name} ]; then
        mkdir ${sample_name}
    fi

    #set minid and mincov thresholds to match PubMLST, treat these as regular allele calls in post processing --minid 97 --mincov 99
    #JK we can't do this because the ngmaster arguments don't work (bug in ngmaster)
    ngmaster --db $ngmasterdb $assembly > ngmaster.tsv

    #post process ngmaster output to get around other bugs in their tool
    ngmaster_postprocess.sh ngmaster.tsv $ngstar $ngmast

    awk -v name=$sample_name 'OFS="\t" { if( NR==1 ){ s="Sample" }else{ s=name }; split(\$3,st,"/"); print s,\$2,st[1],st[2],\$4,\$5,\$6,\$7,\$8,\$9,\$10,\$11,\$12 }' ngmaster_postprocessed.tsv > ${sample_name}/${sample_name}_ngmaster.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        ngmaster: \$( echo \$(ngmaster --version 2>&1) | sed 's/^.*ngmaster //' )
    END_VERSIONS

    """

    stub:
    """

    #Have to grab ngstar ST from ngstar.txt since ngstar ST call doesn't work with updated DB
    grep_regex=\$(awk 'BEGIN{ OFS="\\s+" }{ if (NR==2){ print "\\s+"\$7,\$8,\$9,\$10,\$11,\$12,\$13 } }' ngmaster.tsv)
    ngstar_ST=\$(grep -E \$grep_regex ${params.ngstar} | awk '{ if (NR==1) { print \$1 } }')

    #if we find an allele, swap the "-" in the report with it
    if [ "\$ngstar_ST" != "" ]; then
        sed -i "2s/\\(.*\\)-/\\1\${ngstar_ST}/" ngmaster.tsv  
    fi

    """
}