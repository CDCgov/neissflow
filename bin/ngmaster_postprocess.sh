#!/bin/bash

ngmaster_out=$1
ngstar=$2
ngmast=$3

#Remove similar allele signifiers (~)
sed -i 's/~//g' $ngmaster_out
#sed -i 's/?//g' $ngmaster_out

#Remove instances of multiple alleles (take first allele)
awk 'BEGIN{ FS=OFS="\t";ORS="" }{if (NR==2){ print $1,$2,$3; for (i = 4; i <= NF; i++){ if ($i ~ /,/){ split($i,a,","); print "\t"a[1] }else{ print "\t"$i } }; print "\n" }else{ print $0"\n" } }' $ngmaster_out > ngmaster_postprocessed.tsv
ngmaster_out=ngmaster_postprocessed.tsv

#Have to grab ngstar ST from ngstar.txt since ngstar ST call may not work with updated DB
grep_regex=$(awk 'BEGIN{ OFS="\\s+" }{ if (NR==2){ print "\\s+"$6,$7,$8,$9,$10,$11,$12,$13 } }' $ngmaster_out)
ngstar_ST=$(grep -E $grep_regex $ngstar | awk '{ if (NR==1) { print $1 } }')

#if we find an allele, swap the "-" in the report with it
if [ "$ngstar_ST" != "" ]; then
    sed -i "2s/\\(.*\\)-/\\1${ngstar_ST}/" $ngmaster_out
fi

#Also grab ngmast ST since it might not be called due to similar and partial allele signifiers 
ngmaster_called=$(awk '{ if (NR==2){ split($3,st,"/"); print st[1] } }' $ngmaster_out)
if [ "$ngmaster_called" == "-" ]; then
    grep_regex=$(awk 'BEGIN{ OFS="\\s+" }{ if (NR==2){ print "\\s+"$4,$5 } }' $ngmaster_out)
    ngmast_ST=$(grep -E $grep_regex $ngmast | awk '{ if (NR==1) { print $1 } }')

    #if we find an allele, swap the "-" in the report with it
    if [ "$ngmast_ST" != "" ] && [ "$ngstar_ST" != "" ]; then
        sed -i "2s/\\(.*\\)-/\\1${ngmast_ST}/" $ngmaster_out
    elif [ "$ngmast_ST" != "" ] && [ "$ngstar_ST" == "" ]; then
        sed -i "2s/-\/-/${ngmast_ST}\/-/" $ngmaster_out
    fi
fi