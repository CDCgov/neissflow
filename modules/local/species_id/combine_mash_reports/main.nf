process COMBINE_MASH_REPORTS {
    label 'process_low'

    container "https://depot.galaxyproject.org/singularity/centos:7.9.2009"

    input:
    path(tsv_paths)
    val(prefix)

    output:
    path '*Mash_top_hit_report.tsv', emit: top_hits
    path '*Mash_contaminants.tsv'  , emit: contams
    path '*Mash_plasmids.tsv'      , emit: plasmids
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """

        header=( "ID" "ident" "hashes" "median_mult" "p_val" "hit_name" )

        echo \${header[@]} | sed 's/ /\t/g' > ${prefix}_Mash_top_hit_report.tsv
        echo \${header[@]} | sed 's/ /\t/g' > ${prefix}_Mash_contaminants.tsv
        echo \${header[@]} | sed 's/ /\t/g' > ${prefix}_Mash_plasmids.tsv

        for file in $tsv_paths; do
            awk -v prefix=${prefix} '
            function basename(file)
            { 
                sub(".*/", "", file)
                return file 
            } 
            BEGIN{ OFS="\t"; max_id_hash=0; I=""; II=""; III=""; IV=""; V="" }
            { 
                split(\$2,hash,"/")
                n=split(\$5,f,"-")
                if( \$1+(hash[1]/hash[2]) > max_id_hash && hash[2] == 1000 && f[n-1] !~ /^p/ && f[n-1] !~ /Kingella_kingae_KKC2005004457.fna/ )
                { 
                    max_id_hash=\$1+(hash[1]/hash[2])
                    I=\$1; II=\$2; III=\$3; IV=\$4; V=\$5 
                }
                if( \$1 >= 0.95 && (hash[1]/hash[2]) >= 0.95 )
                { 
                    split(basename(FILENAME),sample,".")
                    n=split(\$5,f,"-")
                    split(f[n],five,".")
                    if( \$5 !~ /Neisseria/ && f[n-1] !~ /^p/ && five[1] !~ /Kingella_kingae_KKC2005004457/ )
                    {
                        print sample[1],\$1,\$2,\$3,\$4,five[1] >> prefix"_Mash_contaminants.tsv"
                    }
                    else if( f[n-1] ~ /^p/ || five[1] ~ /Kingella_kingae_KKC2005004457/ )
                    {
                        name=f[n-1]"-"five[1]
                        print sample[1],\$1,\$2,\$3,\$4,name >> prefix"_Mash_plasmids.tsv"
                    }
                }  
            }
            END{ 
                split(basename(FILENAME),sample,".")
                n=split(V,f,"-")
                split(f[n],five,".")
                print sample[1],I,II,III,IV,five[1] 
            }' \$file >> ${prefix}_Mash_top_hit_report.tsv
        done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Awk: \$(awk --version 2>&1 | sed -n 1p | sed 's/GNU Awk //')
    END_VERSIONS
    """
}