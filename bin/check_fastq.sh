#!/bin/bash
usage="$(basename "$0") [-h] [-i <INPUT FILE>]

Script check FASTQ files

Arguments:
    -h  show this help text
    -i  full path to input FASTQ file"

while getopts ":hi:" option; do 
    case $option in 
        h) echo "$usage"
            exit ;;
        i) file=$OPTARG 
         if [ ! -f "$file" ]; then
            echo "Error: Input FASTQ path $file does not exist."
            exit 1
         fi ;;
        :) echo "Option -${OPTARG} requires an argument."
            exit 1 ;;
        ?) echo "Invalid option: -${OPTARG}"
            exit 1 ;;
    esac 
done 

if ! [[ $file =~ \S*_(1|2|01|02)\.(fast|f)q.gz || $file =~ \S*_(R1|R2).*\.(fast|f)q.gz ]]; then
    echo -n "1,$file"
    exit 1
fi

size=$(stat -c %s $file)

if (( size >= 1000000000 )); then
    echo -n "3,$file"
    exit 1
fi

first=$(zcat $file 2>/dev/null | awk 'NR%4==1 { print 0; if( $0 !~ /^@.{1,}/){ print 1 } }' | awk '{ sum += $0 }END{ print sum }')
second=$(zcat $file 2>/dev/null | awk 'NR%4==2 { print 0; if( $0 !~ /^[ACTGNactgn]{1,}$/){ print 1 } }' | awk '{ sum += $0 }END{ print sum }')
third=$(zcat $file 2>/dev/null | awk 'NR%4==3 { print 0; if( $0 !~ /^\+$/){ print 1 } }' | awk '{ sum += $0 }END{ print sum }')
forth=$(zcat $file 2>/dev/null | awk '!(NR%4) { print 0; if( $0 !~ /^[\x21-\x7e]+$/){ print 1 } }' | awk '{ sum += $0 }END{ print sum }')

if (($(($first+$second+$third+$forth)) != 0)); then
    echo -n "2,$file"
    exit 1
fi 
echo -n "0,$file"