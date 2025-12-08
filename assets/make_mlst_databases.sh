#!/bin/bash


usage="$(basename "$0") [-h] [-k <KEY NAME>] [-r <REPO>] [-p <MLST DIR> ] [-b <BLAST DIR> ] [-t <TOKEN DIR>]

Script to download PubMLST scheme and alleles and make BLAST database

Arguments:
    -h  show this help text
    -k  PubMLST API Key Name
    -r  Full path to cloned BIGSdb_downloader repo
    -p  Full path to directory to write PubMLST database to
    -b  Full path to directory to write BLAST database to
    -t  Full path to directory where API client key and secret have been written to during setup"

while getopts ":hk:r:p:b:t:" option; do 
    case $option in 
        h) echo "$usage"
            exit ;;
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


# Make MLST directory
if [ ! -d "$pubmlst_dir" ]; then
    mkdir "$pubmlst_dir"
    mkdir "${pubmlst_dir}/neisseria"
elif [ ! -d "$pubmlst_dir/neisseria" ]; then
    mkdir "${pubmlst_dir}/neisseria"
elif [ -n "$(ls -A "${pubmlst_dir}/neisseria" 2>/dev/null)" ]; then
    #Save off old DB files just in case
    for file in ${pubmlst_dir}/neisseria/*; do
        if [ -f "$file" ]; then
            mv "$file" "$file.old"
        fi
    done
fi

# Make BLAST db directory
if [ ! -d "$blast_dir" ]; then
    mkdir "$blast_dir"
elif [ -n "$(ls -A "${blast_dir}" 2>/dev/null)" ]; then
    #Save off old DB files just in case
    for file in ${blast_dir}/*; do
        if [ -f "$file" ]; then
            mv "$file" "$file.old"
        fi
    done
fi

python3 ${repo_dir}/bigsdb_downloader.py \
    --key_name "$key_name" \
    --site PubMLST \
    --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/schemes/1/profiles_csv" \
    > "${pubmlst_dir}/neisseria/neisseria.txt"

python3 ${repo_dir}/bigsdb_downloader.py \
    --key_name "$key_name" \
    --site PubMLST \
    --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/abcZ/alleles_fasta" \
    > "${pubmlst_dir}/neisseria/abcZ.tfa"

python3 ${repo_dir}/bigsdb_downloader.py \
    --key_name "$key_name" \
    --site PubMLST \
    --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/adk/alleles_fasta" \
    > "${pubmlst_dir}/neisseria/adk.tfa"

python3 ${repo_dir}/bigsdb_downloader.py \
    --key_name "$key_name" \
    --site PubMLST \
    --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/aroE/alleles_fasta" \
    > "${pubmlst_dir}/neisseria/aroE.tfa"

python3 ${repo_dir}/bigsdb_downloader.py \
    --key_name "$key_name" \
    --site PubMLST \
    --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/fumC/alleles_fasta" \
    > "${pubmlst_dir}/neisseria/fumC.tfa"

python3 ${repo_dir}/bigsdb_downloader.py \
    --key_name "$key_name" \
    --site PubMLST \
    --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/gdh/alleles_fasta" \
    > "${pubmlst_dir}/neisseria/gdh.tfa"

python3 ${repo_dir}/bigsdb_downloader.py \
    --key_name "$key_name" \
    --site PubMLST \
    --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/pdhC/alleles_fasta" \
    > "${pubmlst_dir}/neisseria/pdhC.tfa"

python3 ${repo_dir}/bigsdb_downloader.py \
    --key_name "$key_name" \
    --site PubMLST \
    --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/loci/pgm/alleles_fasta" \
    > "${pubmlst_dir}/neisseria/pgm.tfa"

for file in ${pubmlst_dir}/neisseria/*.tfa; do
    awk '{ if( $0 ~ /^>/ ){ print ">neisseria."substr($0, 2) }else{ print $0 } }' $file >> ${blast_dir}/mlst.fa
done

makeblastdb -in ${blast_dir}/mlst.fa -dbtype 'nucl' -out ${blast_dir}/mlst.fa


#NG STAR https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/schemes/67
#NG-MAST https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/schemes/71

