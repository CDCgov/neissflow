process CHECK_FASTQS {
    tag "$sample_name"
    label 'process_low' 

    container "https://depot.galaxyproject.org/singularity/centos:7.9.2009"

    input:
    tuple val(sample_name), path(reads)

    output:
    tuple val(sample_name), path(reads), emit: pass
    path 'versions.yml'                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script: 
    read_1_path = reads[0]
    read_2_path = reads[1]
    """

    check_name () {
        if ! [[ \$1 =~ \\S*_(1|2|01|02)\\.(fast|f)q.gz || \$1 =~ \\S*_(R1|R2).*\\.(fast|f)q.gz ]]; then
            exit 1
        fi
        echo 0
    }

    check_format () {
        first=\$(zcat \$1 2>/dev/null | awk 'NR%4==1 { print 0; if( \$0 !~ /^@.{1,}/){ print 1 } }' | awk '{ sum += \$0 }END{ print sum }')
        second=\$(zcat \$1 2>/dev/null | awk 'NR%4==2 { print 0; if( \$0 !~ /^[ACTGNactgn]{1,}\$/){ print 1 } }' | awk '{ sum += \$0 }END{ print sum }')
        third=\$(zcat \$1 2>/dev/null | awk 'NR%4==3 { print 0; if( \$0 !~ /^\\+.*/){ print 1 } }' | awk '{ sum += \$0 }END{ print sum }')
        forth=\$(zcat \$1 2>/dev/null | awk '!(NR%4) { print 0; if( \$0 !~ /^[\\x21-\\x7e]+\$/){ print 1 } }' | awk '{ sum += \$0 }END{ print sum }')

        if ((\$((\$first+\$second+\$third+\$forth)) != 0)); then
            exit 1
        fi 
        echo 0
    }

    pass1=\$(check_name ${read_1_path})+\$(check_format ${read_1_path})
    pass2=\$(check_name ${read_2_path})+\$(check_format ${read_2_path})

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Awk: \$(awk --version 2>&1 | sed -n 1p | sed 's/GNU Awk //')
    END_VERSIONS

    """
}