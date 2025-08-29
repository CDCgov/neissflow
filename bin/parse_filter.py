#!/usr/bin/env python
### IMPORT PYTHON MODULES  #####
 
import json
import os
import csv
import argparse


### Function to parse relevant JSON fastp report metrics into a dictionary ###

def make_dict(json_file):
    '''
    input:
        json_file - name of json file with fastp output
    output:
        final_summary - fastp QC metrics for single isolate (dictionary)
    '''
    f = open(json_file)
    summary = json.load(f)

    final_summary = dict()
    final_summary['isolate'] = os.path.splitext(json_file)[0]
    for param in summary['summary']['before_filtering'].keys():
        final_summary['before_filtering_'+param] = summary['summary']['before_filtering'][param]
    for param in summary['summary']['after_filtering'].keys():
        final_summary['after_filtering_'+param] = summary['summary']['after_filtering'][param]
    final_summary.update(summary['filtering_result'])

    f.close()

    return final_summary

### Function to write relevant fastp report metrics to a TSV file ###

def writeTSV(final_summary):
    '''
    input: 
        final_summary - fastp QC metrics for single isolate (dictionary)
    '''
    agg_summary = [final_summary]

    with open(final_summary['isolate']+'_inter_report.tsv','w',newline='') as output_file:
        dict_writer = csv.DictWriter(output_file, fieldnames=agg_summary[0].keys(), delimiter='\t')
        dict_writer.writeheader()
        dict_writer.writerows(agg_summary)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
                        prog='python3 parse_filter.py',
                        description='This program generates a TSV QC report from the FASTP JSON report and removes low quality isolates')
        
    parser.add_argument('-i','--in_file', type=str, required=True, help='JSON file')
    parser.add_argument('-o','--out', type=str, required=True, help='Full path of pipeline output directory')
        
    args = parser.parse_args()

    json_file = args.in_file
    out = args.out

    final_summary = make_dict(json_file)
    writeTSV(final_summary)