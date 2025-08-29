#!/bin/bash

align=$1
tree=$2
mono_nuc=$3
samples=$4

samples="${samples:1:-1}"
IFS=', ' read -r -a sample_list <<< "$samples"

num_samples="${#sample_list[@]}"

# Number of alignments
num_align=$(grep ">" "$align" | wc -l)

# Extract alignment information
align_info=$(awk 'BEGIN{ i=0; count=0 }{
    if ($1 ~ /^>.*/ ) {
        i += 1
        lengths[i] = 0
    } else if ($0 !~ /^[ATGCN\-atgcn]+\s*$/ ) {
        count += 1
        lengths[i] += length($0)
    } else {
        lengths[i] += length($0)
    }
} END {
    len1 = lengths[1]
    no_mismatch = "true"
    for (j in lengths) {
        if (lengths[j] != len1) {
            no_mismatch = "false"
        }
    }
    print no_mismatch, count
}' "$align")

# Read alignment information
read -a arr <<< "$align_info"
same_length="${arr[0]}" # true if all samples in core alignment are the same length as the reference
bad_nuc_lcount="${arr[1]}" # number of lines in the core alignment file with invalid characters in the nucleotide sequence

# Extract stats
stats=$(egrep -o '[^)]:[0-9]+\.[0-9]+' "$tree" | egrep -o '[0-9]+\.[0-9]+' | datamash mean 1 sstdev 1)
read -a arr2 <<< "$stats"
mean=$(echo "${arr2[0]}" | awk -F"E" 'BEGIN{OFMT="%10.15f"} {print $1 * (10 ^ $2)}')
std=$(echo "${arr2[1]}" | awk -F"E" 'BEGIN{OFMT="%10.15f"} {print $1 * (10 ^ $2)}')
outlier_cutoff=$(echo "$mean + ( 2 * $std )" | bc) # if the branch length > the mean + 2 times the standard deviation, consider it an outlier

# Initialize counters and arrays
declare -i count=0 # count of samples in tree
all_in_tree='true' # will remain true if all of the samples are found in the Newick tree
declare -a outliers

# Process each sample
for i in $sample_list; do
    pattern="${i}:[0-9]+\.[0-9]+"
    found=$(egrep -o "$pattern" "$tree")
    
    if [ -z "$found" ]; then
        all_in_tree='false'
    else
        branch_len=$(echo "$found" | egrep -o '[0-9]+\.[0-9]+')
        if (( $(echo "$branch_len > $outlier_cutoff" | bc -l) )); then
            outliers+=("$i")
        fi
    fi
    (( count++ ))
done

#Get monomorphic nuc core alignment size

core_size=$(awk 'NR==1 { sum=0; for(i=1;i<=NF;i++){ sum+=$i }; print sum }' $mono_nuc)

# Write QC report
printf "%s\t%s\t%s\t%s\n" "QC Parameter" "Accepted Value" "Actual Value" "Pass/Fail" > phylogeny_qc_report.tsv

# Number of samples aligned
if [ "$num_samples" -eq "$((num_align - 1))" ]; then
    out="pass"
else
    out="fail"
fi
printf "%s\t%s\t%s\t%s\n" "Num_Samples_Aligned" "$num_samples" "$((num_align - 1))" "$out" >> phylogeny_qc_report.tsv

# Do lengths match reference length
if [ "$same_length" == "true" ]; then
    out="pass"
else
    out="fail"
fi
printf "%s\t%s\t%s\t%s\n" "Match_Ref_Length" "true" "$same_length" "$out" >> phylogeny_qc_report.tsv

# Number of lines with invalid nucleotide chars
if [ "$bad_nuc_lcount" -eq 0 ]; then
    out="pass"
else
    out="fail"
fi
printf "%s\t%s\t%s\t%s\n" "Num_Lines_w_Invalid_Nuc" "0" "$bad_nuc_lcount" "$out" >> phylogeny_qc_report.tsv

# All samples present in Newick tree
if [ "$all_in_tree" == "true" ]; then
    out="pass"
else
    out="fail"
fi
printf "%s\t%s\t%s\t%s\n" "All_Present_in_Tree" "true" "$all_in_tree" "$out" >> phylogeny_qc_report.tsv

printf "%s\t%s\t%s\t%s\n" "Num_Outliers" "-" "${#outliers[@]}" "NA" >> phylogeny_qc_report.tsv

# Size of Core (excluding portions aligned with N and -)
printf "%s\t%s\t%s\t%s\n" "Core_Mono_Nuc_bp_Count" "-" "$core_size" "NA" >> phylogeny_qc_report.tsv