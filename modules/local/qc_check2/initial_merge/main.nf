process INITIAL_MERGE {
    label 'process_single'

    container "https://depot.galaxyproject.org/singularity/centos:7.9.2009"

    input:
    path(fastq_qc)
    path(species)
    path(fa19_coverage)
    path(assembly)

    output:
    path 'initial_merge.tsv', emit: report
    path "versions.yml"     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """

    header1=\$(head -n 1 $fa19_coverage)
    header2=\$(cut -f 2- $species | head -n 1)
    header3=\$(cut -f 2- $assembly | head -n 1)
    header4=\$(cut -f 2- $fastq_qc | head -n 1)
    printf "%s\t%s\t%s\t%s\n" "\$header1" "\$header2" "\$header3" "\$header4" > initial_merge.tsv
    join -j 1 -t \$'\t' -o 0,1.2,2.2,2.3,2.4,2.5,2.6 <(sort -k 1b,1 $fa19_coverage) <(sort -k 1b,1 $species) \
    | join -j 1 -t \$'\t' -o 0,1.2,1.3,1.4,1.5,1.6,1.7,2.2,2.3,2.4,2.5,2.6,2.7,2.8,2.9,2.10,2.11,2.12,2.13,2.14,2.15,2.16,2.17,2.18 \
     - <(sort -k 1b,1 $assembly) | join -a1 -a2 -e 'skip' -j 1 -t \$'\t' -o 0,1.2,1.3,1.4,1.5,1.6,1.7,1.8,1.9,1.10,1.11,1.12,1.13,1.14,1.15,1.16,1.17,1.18,1.19,1.20,1.21,1.22,1.23,1.24,2.2,2.3,2.4,2.5,2.6,2.7,2.8,2.9,2.10,2.11,2.12,2.13,2.14,2.15,2.16,2.17,2.18,2.19,2.20,2.21,2.22,2.23,2.24 - <(tail -n +2 $fastq_qc | sort -k 1b,1) >> initial_merge.tsv


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version 2>&1 | sed 's/GNU bash, version //; s/(.*//' | awk 'NR==1{ print \$0 }')
    END_VERSIONS
    """
}