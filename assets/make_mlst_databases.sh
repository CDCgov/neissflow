#!/bin/bash


usage="$(basename "$0") [-h] [-d mlst|ngmaster|penAporB][-k <KEY NAME>] [-r <REPO>] [-p <PUBMLST DIR> ] [-b <BLAST DIR> ] [-t <TOKEN DIR>]

Script to download PubMLST scheme and alleles and make BLAST database

Arguments:
    -h  show this help text
    -d  Database to download [mlst, ngmaster, penAporB]
    -k  PubMLST API Key Name
    -r  Full path to cloned BIGSdb_downloader repo
    -p  Full path to directory to write PubMLST allele sequences and scheme to
    -b  Full path to directory to write BLAST database to
    -t  Full path to directory where API client key and secret have been written to during setup"

while getopts ":hd:k:r:p:b:t:" option; do 
    case $option in 
        h) echo "$usage"
            exit ;;
        d) db=$OPTARG
            if ! [[ $db == "mlst" || $db == "ngmaster" || $db == "penAporB" ]]; then
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

### Make all necessary directories exist / ensure existing db files are not overwritten ###
makedirs() {
    local p_dir=$1
    local scheme=$2
    local b_dir=$3

    if $4; then
        # Make MLST directory
        if [ ! -d "$p_dir" ]; then
            echo "Making $p_dir PubMLST dir"
            mkdir "$p_dir"
            mkdir "${p_dir}/${scheme}"
        elif [ ! -d "$p_dir/${scheme}" ]; then
            mkdir "${p_dir}/${scheme}"
        elif [ -n "$(ls -A "${p_dir}/${scheme}" 2>/dev/null)" ]; then
            #Save off old DB files just in case
            for file in ${p_dir}/${scheme}/*; do
                if [ -f "$file" ]; then
                    echo "renaming $file to ${file}.old"
                    mv "$file" "${file}.old"
                fi
            done
        fi
    fi

    # Make BLAST db directory
    if [ ! -d "$b_dir" ]; then
        echo "Making $b_dir BLAST db dir"
        mkdir "$b_dir"
    elif [ -n "$(ls -A "${b_dir}" 2>/dev/null)" ]; then
        #Save off old DB files just in case
        for file in ${b_dir}/*; do
            if [ -f "$file" ]; then
                echo "renaming $file to ${file}.old"
                mv "$file" "${file}.old"
            fi
        done
    fi
}

if [[ $db == "mlst" ]]; then
    makedirs "$pubmlst_dir" "neisseria" "$blast_dir" true
elif [[ $db == "ngmaster" ]]; then
    makedirs "$pubmlst_dir" "ngmast" "$blast_dir" true
    makedirs "$pubmlst_dir" "ngstar" "$blast_dir" true
else 
    makedirs "" "" "$blast_dir" false
fi

### Download scheme and allele sequences from PubMLST ###
download(){
    local r_dir=$1
    local key=$2
    local url=$3
    local p_dir=$4
    local scheme=$5
    local file=$6
    echo "Downloading $file from PubMLST"
    python3 ${r_dir}/bigsdb_downloader.py \
        --key_name "$key" \
        --site PubMLST \
        --url "https://rest.pubmlst.org/db/pubmlst_neisseria_seqdef/${url}" \
        > "${p_dir}/${scheme}/${file}"
}

if [[ $db == "mlst" ]]; then
    download "$repo_dir" "$key_name" "schemes/1/profiles_csv" "$pubmlst_dir" "neisseria" "neisseria.txt"
    download "$repo_dir" "$key_name" "loci/abcZ/alleles_fasta" "$pubmlst_dir" "neisseria" "abcZ.tfa"
    download "$repo_dir" "$key_name" "loci/adk/alleles_fasta" "$pubmlst_dir" "neisseria" "adk.tfa"
    download "$repo_dir" "$key_name" "loci/aroE/alleles_fasta" "$pubmlst_dir" "neisseria" "aroE.tfa"
    download "$repo_dir" "$key_name" "loci/fumC/alleles_fasta" "$pubmlst_dir" "neisseria" "fumC.tfa"
    download "$repo_dir" "$key_name" "loci/gdh/alleles_fasta" "$pubmlst_dir" "neisseria" "gdh.tfa"
    download "$repo_dir" "$key_name" "loci/pdhC/alleles_fasta" "$pubmlst_dir" "neisseria" "pdhC.tfa"
    download "$repo_dir" "$key_name" "loci/pgm/alleles_fasta" "$pubmlst_dir" "neisseria" "pgm.tfa"
elif [[ $db == "ngmaster" ]]; then
    download "$repo_dir" "$key_name" "schemes/67/profiles_csv" "$pubmlst_dir" "ngstar" "ngstar.txt"
    download "$repo_dir" "$key_name" "loci/NG_porB/alleles_fasta" "$pubmlst_dir" "ngstar" "porB.tfa"
    download "$repo_dir" "$key_name" "loci/NG_gyrA/alleles_fasta" "$pubmlst_dir" "ngstar" "gyrA.tfa"
    download "$repo_dir" "$key_name" "loci/NG_parC/alleles_fasta" "$pubmlst_dir" "ngstar" "parC.tfa"
    download "$repo_dir" "$key_name" "loci/NG_23S/alleles_fasta" "$pubmlst_dir" "ngstar" "23S.tfa"
    download "$repo_dir" "$key_name" "loci/NG_ponA/alleles_fasta" "$pubmlst_dir" "ngstar" "ponA.tfa"
    download "$repo_dir" "$key_name" "loci/'mtrR/alleles_fasta" "$pubmlst_dir" "ngstar" "mtrR.tfa"
    download "$repo_dir" "$key_name" "loci/NEIS1753/alleles_fasta" "$pubmlst_dir" "ngstar" "penA.tfa"

    download "$repo_dir" "$key_name" "schemes/71/profiles_csv" "$pubmlst_dir" "ngmast" "ngmast.txt"
    download "$repo_dir" "$key_name" "loci/NG-MAST_porB/alleles_fasta" "$pubmlst_dir" "ngmast" "porB.tfa"
    download "$repo_dir" "$key_name" "loci/NG-MAST_tbpB/alleles_fasta" "$pubmlst_dir" "ngmast" "tbpB.tfa"
else 
    echo ""
    echo "Downloading penAdb.fa"
    curl --output "${blast_dir}/penAdb.fa" 'https://ngstar.canada.ca/alleles/download?lang=en&loci_name=penA'
    echo ""
    echo "Downloading porBdb.fa"
    curl --output "${blast_dir}/porBdb.fa" 'https://ngstar.canada.ca/alleles/download?lang=en&loci_name=porB'
    echo ""
fi

### Create allele fasta to use for making BLAST db ###
all_allele_fasta(){
    local p_dir=$1
    local scheme=$2
    local b_dir=$3
    for file in ${p_dir}/${scheme}/*.tfa; do
        if [[ $scheme == "ngstar" ]]; then
            #since they prefix them with "NG_" now and that breaks NGMASTER
            awk -vName=${scheme} '{ if( $0 ~ /^>/ ){ gsub("NG_","",$0); gsub(/\x27/,"",$0); gsub("NEIS1753","penA",$0); print ">"Name"."substr($0, 2) }else{ print $0 } }' $file >> ${b_dir}/mlst.fa
            awk '{ gsub("NG_","",$0); print $0 }' "${p_dir}/${scheme}/porB.tfa" > "${p_dir}/${scheme}/tmp.txt"
            mv "${p_dir}/${scheme}/tmp.txt" "${p_dir}/${scheme}/porB.tfa"
        elif [[ $scheme == "ngmast" ]]; then
            #since they prefix them with "NG-MAST" now and that breaks NGMASTER"
            awk -vName=${scheme} '{ if( $0 ~ /^>/ ){ print ">"Name"."substr($0, 10) }else{ print $0 } }' $file >> ${b_dir}/mlst.fa
            awk '{ gsub("NG-MAST_","",$0); print $0 }' "${p_dir}/${scheme}/porB.tfa" > "${p_dir}/${scheme}/tmp.txt"
            mv "${p_dir}/${scheme}/tmp.txt" "${p_dir}/${scheme}/porB.tfa"
        else
            awk -vName=${scheme} '{ if( $0 ~ /^>/ ){ print ">"Name"."substr($0, 2) }else{ print $0 } }' $file >> ${b_dir}/mlst.fa
        fi

    done
}

### Revise NG-MAST and NG-STAR schemes so they are compatible with NGMASTER ###
revise_scheme(){
    local p_dir=$1
    local scheme=$2
    if [[ $scheme == "ngstar" ]]; then
        awk '{ gsub("NG_","",$0); gsub(/\x27/,"",$0); gsub("NEIS1753","penA",$0); print $0 }' "${p_dir}/${scheme}/${scheme}.txt" > "${p_dir}/${scheme}/tmp.txt"
    else
        awk '{ gsub("NG-MAST_","",$0); print $0 }' "${p_dir}/${scheme}/${scheme}.txt" > "${p_dir}/${scheme}/tmp.txt"
    fi
    mv "${p_dir}/${scheme}/tmp.txt" "${p_dir}/${scheme}/${scheme}.txt"
}

if [[ $db == "mlst" ]]; then
    all_allele_fasta "$pubmlst_dir" "neisseria" "$blast_dir"
    echo "Making BLAST db from ${blast_dir}/mlst.fa for mlst"
    makeblastdb -in "${blast_dir}/mlst.fa" -dbtype 'nucl' -out "${blast_dir}/mlst.fa"
elif [[ $db == "ngmaster" ]]; then
    all_allele_fasta "$pubmlst_dir" "ngstar" "$blast_dir"
    all_allele_fasta "$pubmlst_dir" "ngmast" "$blast_dir"
    revise_scheme "$pubmlst_dir" "ngstar"
    revise_scheme "$pubmlst_dir" "ngmast"
    echo "Making BLAST db from ${blast_dir}/mlst.fa for NGMASTER"
    makeblastdb -in "${blast_dir}/mlst.fa" -dbtype 'nucl' -out "${blast_dir}/mlst.fa"
else 
    echo "Making BLAST db from ${blast_dir}/penAdb.fa for penA allele calling"
    makeblastdb -in "${blast_dir}/penAdb.fa" -dbtype 'nucl' -out "${blast_dir}/penAdb"
    echo "Making BLAST db from ${blast_dir}/porBdb.fa for porB allele calling"
    makeblastdb -in "${blast_dir}/porBdb.fa" -dbtype 'nucl' -out "${blast_dir}/porBdb"
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

