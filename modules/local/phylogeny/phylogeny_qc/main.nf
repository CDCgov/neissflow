process PHYLOGENY_QC {
    label 'process_low'

    container "https://depot.galaxyproject.org/singularity/centos:7.9.2009"

    input:
    path(align)
    path(tree)
    val(sample_list)
    path(mono_nuc)

    output:
    path "phylogeny_qc_report.tsv", emit: qc_report
    path 'versions.yml'           , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    """
    
    phylogeny_qc.sh $align $tree $mono_nuc "$sample_list"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Awk: \$(awk --version 2>&1 | sed -n 1p | sed 's/GNU Awk //')
    END_VERSIONS

    """

    stub:
    """
    num_align=\$(grep ">" $align | wc -l)

    align_info=\$(awk 'BEGIN{ i=0; count=0 }{ if( \$1 ~ /^>.*/ ){ i+=1; lengths[i]=0 }else if( \$0 !~ /^[ATGCN\\-atgcn]+\\s*\$/ ){ count+=1; lengths[i] += length(\$0) }else{ lengths[i] += length(\$0) } }END{ len1=lengths[1]; no_mismatch="true"; for( j in lengths ){ if( lengths[j] != len1 ){ no_mismatch="false" } }; print no_mismatch,count }' $align)
    read -a arr <<< "\$align_info"
    same_length="\${arr[0]}" #true if all samples in core alignment are the same length as the reference
    bad_nuc_lcount="\${arr[1]}" #number of lines in the core alignment file with invalid characters in the nucleotide sequence 

    stats=\$(egrep -o '[^)]:[0-9]+\\.[0-9]+' $tree | egrep -o '[0-9]+\\.[0-9]+' | datamash mean 1 sstdev 1)
    read -a arr2 <<< "\$stats"
    mean="\${arr2[0]}"
    std="\${arr2[1]}"

    outlier_cutoff=\$(echo "\$mean + ( 2 * \$std )" | bc) #if the branch length > the mean + 2 times the standard deviation, we consider it to be an outlier

    declare -i count
    count=0 #count of samples in tree
    all_in_tree='true' #will remain true if all of the samples are found in the newick tree
    declare -a outliers
    for i in $sample_list; do
        pattern="\${i}\\x3A[0-9]+\\.[0-9]+"
        found=\$(egrep -o "\$pattern" $tree)
        if [ -z "\$found" ]; then
            all_in_tree='false'
        else
            branch_len=\$(egrep -o '[0-9]+\\.[0-9]+' "\$found")
            if [[ "\$branch_len" -gt "\$outlier_cutoff" ]]; then
                outliers+=("\$i")
            fi
        fi
        (( count++ ))
    done

    printf %s/t%s/t%s/t%s/n "QC Parameter" "Accepted Value" "Actual Value" "Pass/Fail" > phylogeny_qc_report.tsv

    if [[ ${num_samples} -eq \${num_align}-1 ]]; then
        out="pass"
    else 
        out="fail"
    fi
    printf %s/t%s/t%s/t%s/n "Number of Samples Aligned" $num_samples \${num_align}-1 \$out >> phylogeny_qc_report.tsv

    if [[ ${num_samples} -eq \${num_align}-1 ]]; then
        out="pass"
    else
        out="fail"
    fi
    printf %s/t%s/t%s/t%s/n "Do Lengths Match Reference Length" "true" \$same_length \$out >> phylogeny_qc_report.tsv

    if [[ \${bad_nuc_lcounts} -eq 0 ]]; then
        out="pass"
    else
        out="fail"
    fi
    printf %s/t%s/t%s/t%s/n "Number of Lines in Align with Invalid Nucleotide Chars" "0" \${bad_nuc_lcounts} \$out >> phylogeny_qc_report.tsv

    if [ "\${all_in_tree}" == "true" ]; then
        out="pass"
    else
        out="fail"
    fi
    printf %s/t%s/t%s/t%s/n "All Samples are Present in Newick Tree" "true" \${all_in_tree} \$out >> phylogeny_qc_report.tsv

    if [[ \${#outliers[@]} -eq 0 ]]; then
        out="pass"
    else
        out="fail"
        out_list=\$(IFS=, ; echo "\${outliers[*]}")
    fi
    printf %s/t%s/t%s/t%s/n "Outlier Samples Found" "NA" \${out_list} \$out >> phylogeny_qc_report.tsv

    """
}


