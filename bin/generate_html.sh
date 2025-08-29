#!/bin/bash

usage="$(basename "$0") [-h] [-p <INPUT PNG>] [-c <INPUT isolate clusters>]

Script generate html report

Arguments:
    -h  show this help text
    -i  full path to input FASTQ file"

while getopts ":hp:c:" option; do 
    case $option in 
        h) echo "$usage"
            exit ;;
        p) png=$OPTARG 
         if [ ! -f "$png" ]; then
            echo "Error: Input PNG $png does not exist."
            exit 1
         fi ;;
        c) isolate_clusters=$OPTARG 
         if [ ! -f "$isolate_clusters" ]; then
            echo "Error: Input isolate clusters $isolate_clusters does not exist."
            exit 1
         fi ;;
        :) echo "Option -${OPTARG} requires an argument."
            exit 1 ;;
        ?) echo "Invalid option: -${OPTARG}"
            exit 1 ;;
    esac 
done 

clusters=$(sed -e 's/\$/<\/li>/g' $isolate_clusters | sed -e 's/^/<li>/g')
if [ -z $clusters ]; then
    clusters='No potential outbreaks identified'
fi
(
    printf "<html>\n<head>\n<title>Phylogeny Report</title>\n</head>\n<body>\n" 
    echo "<h1>Phylogeny Report</h1>"
    echo "<h2>Phylogenetic Tree</h2>"
    printf  "<img src=\"$png\" alt=\"Phylogenetic Tree\" width=\"750\" height=\"1500\">\n"
    printf  "<h2>Potential Outbreak Clusters:</h2>\n<ul>"
    printf  '%s' "$clusters"
    echo "</ul>"
    printf "</body>\n</html>\n"
) > phylogeny_report.html
