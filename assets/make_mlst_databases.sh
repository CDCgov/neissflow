#!/bin/bash


usage="$(basename "$0") [-h] [-db mlst|ngmaster|penAporB][-k <KEY NAME>] [-r <REPO>] [-p <MLST DIR> ] [-b <BLAST DIR> ] [-t <TOKEN DIR>]

Script to download PubMLST scheme and alleles and make BLAST database

Arguments:
    -h  show this help text
    -d  Database to download [mlst, ngmaster, penAporB]
    -k  PubMLST API Key Name
    -r  Full path to cloned BIGSdb_downloader repo
    -p  Full path to directory to write PubMLST database to
    -b  Full path to directory to write BLAST database to
    -t  Full path to directory where API client key and secret have been written to during setup"

while getopts ":hd:k:r:p:b:t:" option; do 
    case $option in 
        h) echo "$usage"
            exit ;;
        d) db=$OPTARG
            if ! [[ $db == "mlst" || $db == "ngmaster" || $db == "penAporB" ] ]; then
                echo "Error: Input database name $db is invalid, must be mlst, ngmaster, or penAporB"
                exit 1
            fi ;;
        r) repo_dir=$OPTARG 
         if [ ! -d "$repo_dir" ]; then
            echo "Error: Input BIGSdb_downloader repo directory path $repo_dir does not exist."
            exit 1
         fi ;;
        k) key_name=$OPTARG ;;
        p) pubmlst_dir=$OPTARG ;;
        b) blast_dir=$OPTARG ;;
        t) token_dir=$OPTARG 
         if [ ! -d "$token_dir" ]; then
            echo "Error: Input token directory path $token_dir does not exist."
            exit 1
         fi ;;
        :) echo "Option -${OPTARG} requires an argument."
            exit 1 ;;
        ?) echo "Invalid option: -${OPTARG}"
            exit 1 ;;
    esac 
done 

makedirs() {
    local p_dir=$1
    local scheme=$2
    local b_dir=$3

    if $4; then
        # Make MLST directory
        if [ ! -d "$p_dir" ]; then
            mkdir "$p_dir"
            mkdir "${p_dir}/${scheme}"
        elif [ ! -d "$p_dir/${scheme}" ]; then
            mkdir "${p_dir}/${scheme}"
        elif [ -n "$(ls -A "${p_dir}/${scheme}" 2>/dev/null)" ]; then
            #Save off old DB files just in case
            for file in ${p_dir}/${scheme}/*; do
                if [ -f "$file" ]; then
                    mv "$file" "$file.old"
                fi
            done
        fi
    fi

    # Make BLAST db directory
    if [ ! -d "$b_dir" ]; then
        mkdir "$b_dir"
    elif [ -n "$(ls -A "${b_dir}" 2>/dev/null)" ]; then
        #Save off old DB files just in case
        for file in ${b_dir}/*; do
            if [ -f "$file" ]; then
                mv "$file" "$file.old"
            fi
        done
    fi
}

if [ $db == "mlst"]; then
    makedirs $pubmlst_dir "neisseria" $blast_dir true
elif [ $db == "ngmaster" ]
    makedirs $pubmlst_dir "ngmast" $blast_dir true
    makedirs $pubmlst_dir "ngstar" $blast_dir true
else 
    makedirs "" "" $blast_dir false
fi

download(){
    local r_dir=$1
    local key=$2
    local url=$3
    local p_dir=$4
    local scheme=$5
    local file=$6

    python3 ${r_dir}/bigsdb_downloader.py \
        --key_name "$key" \
        --site PubMLST \
        --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/${url}" \
        > "${p_dir}/${scheme}/${file}"
}

if [ $db == "mlst"]; then
    download $repo_dir $key_name "schemes/1/profiles_csv" $pubmlst_dir "neisseria" "neisseria.txt"
    download $repo_dir $key_name "loci/abcZ/alleles_fasta" $pubmlst_dir "neisseria" "abcZ.tfa"
    download $repo_dir $key_name "loci/adk/alleles_fasta" $pubmlst_dir "neisseria" "adk.tfa"
    download $repo_dir $key_name "loci/aroE/alleles_fasta" $pubmlst_dir "neisseria" "aroE.tfa"
    download $repo_dir $key_name "loci/fumC/alleles_fasta" $pubmlst_dir "neisseria" "fumC.tfa"
    download $repo_dir $key_name "loci/gdh/alleles_fasta" $pubmlst_dir "neisseria" "gdh.tfa"
    download $repo_dir $key_name "loci/pdhC/alleles_fasta" $pubmlst_dir "neisseria" "pdhC.tfa"
    download $repo_dir $key_name "loci/pgm/alleles_fasta" $pubmlst_dir "neisseria" "pgm.tfa"
elif [ $db == "ngmaster" ]
    download $repo_dir $key_name "schemes/67/profiles_csv" $pubmlst_dir "ngstar" "ngstar.txt"
    download $repo_dir $key_name "loci/NG_porB/alleles_fasta" $pubmlst_dir "ngstar" "porB.tfa"
    download $repo_dir $key_name "loci/NG_gyrA/alleles_fasta" $pubmlst_dir "ngstar" "gyrA.tfa"
    download $repo_dir $key_name "loci/NG_parC/alleles_fasta" $pubmlst_dir "ngstar" "parC.tfa"
    download $repo_dir $key_name "loci/NG_23S/alleles_fasta" $pubmlst_dir "ngstar" "23S.tfa"
    download $repo_dir $key_name "loci/NG_ponA/alleles_fasta" $pubmlst_dir "ngstar" "ponA.tfa"
    download $repo_dir $key_name "loci/'mtrR/alleles_fasta" $pubmlst_dir "ngstar" "mtrR.tfa"
    download $repo_dir $key_name "loci/NEIS1753/alleles_fasta" $pubmlst_dir "ngstar" "penA.tfa"

    download $repo_dir $key_name "schemes/71/profiles_csv" $pubmlst_dir "ngmast" "ngmast.txt"
    download $repo_dir $key_name "loci/NG-MAST_porB/alleles_fasta" $pubmlst_dir "ngmast" "porB.tfa"
    download $repo_dir $key_name "loci/NG-MAST_tbpB/alleles_fasta" $pubmlst_dir "ngmast" "tbpB.tfa"
else 
    # download $repo_dir $key_name "loci/NG-MAST_porB/alleles_fasta" $blast_dir "" "porB.tfa"
    # download $repo_dir $key_name "loci/NG-MAST_tbpB/alleles_fasta" $blast_dir "" "tbpB.tfa"
fi

all_allele_fasta(){
    local p_dir=$1
    local scheme=$2
    local b_dir=$3
    for file in ${pubmlst_dir}/${scheme}/*.tfa; do
        awk -vName=${scheme} '{ if( $0 ~ /^>/ ){ print ">"Name"."substr($0, 2) }else{ print $0 } }' $file >> ${b_dir}/mlst.fa
    done
}

if [ $db == "mlst"]; then
    all_allele_fasta $pubmlst_dir "neisseria" $blast_dir
    makeblastdb -in ${blast_dir}/mlst.fa -dbtype 'nucl' -out ${blast_dir}/mlst.fa
elif [ $db == "ngmaster"]; then
    all_allele_fasta $pubmlst_dir "ngstar" $blast_dir
    all_allele_fasta $pubmlst_dir "ngmast" $blast_dir
    makeblastdb -in ${blast_dir}/mlst.fa -dbtype 'nucl' -out ${blast_dir}/mlst.fa
else 
    ##stuff
fi

# python3 ${repo_dir}/bigsdb_downloader.py \
#     --key_name "$key_name" \
#     --site PubMLST \
#     --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/schemes/1/profiles_csv" \
#     > "${pubmlst_dir}/neisseria/neisseria.txt"

# python3 ${repo_dir}/bigsdb_downloader.py \
#     --key_name "$key_name" \
#     --site PubMLST \
#     --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/abcZ/alleles_fasta" \
#     > "${pubmlst_dir}/neisseria/abcZ.tfa"

# python3 ${repo_dir}/bigsdb_downloader.py \
#     --key_name "$key_name" \
#     --site PubMLST \
#     --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/adk/alleles_fasta" \
#     > "${pubmlst_dir}/neisseria/adk.tfa"

# python3 ${repo_dir}/bigsdb_downloader.py \
#     --key_name "$key_name" \
#     --site PubMLST \
#     --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/aroE/alleles_fasta" \
#     > "${pubmlst_dir}/neisseria/aroE.tfa"

# python3 ${repo_dir}/bigsdb_downloader.py \
#     --key_name "$key_name" \
#     --site PubMLST \
#     --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/fumC/alleles_fasta" \
#     > "${pubmlst_dir}/neisseria/fumC.tfa"

# python3 ${repo_dir}/bigsdb_downloader.py \
#     --key_name "$key_name" \
#     --site PubMLST \
#     --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/gdh/alleles_fasta" \
#     > "${pubmlst_dir}/neisseria/gdh.tfa"

# python3 ${repo_dir}/bigsdb_downloader.py \
#     --key_name "$key_name" \
#     --site PubMLST \
#     --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/pdhC/alleles_fasta" \
#     > "${pubmlst_dir}/neisseria/pdhC.tfa"

# python3 ${repo_dir}/bigsdb_downloader.py \
#     --key_name "$key_name" \
#     --site PubMLST \
#     --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/pgm/alleles_fasta" \
#     > "${pubmlst_dir}/neisseria/pgm.tfa"


#NG STAR https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/schemes/67
#NG-MAST https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/schemes/71

