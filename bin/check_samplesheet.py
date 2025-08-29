#!/usr/bin/env python

import os
import sys
import errno
import argparse
from subprocess import *

#from viralrecon (but edited for neissflow)

def parse_args(args=None):
    Description = "Reformat samplesheet file and check its contents."
    Epilog = "Example usage: python check_samplesheet.py <FILE_IN> <FILE_OUT>"

    parser = argparse.ArgumentParser(description=Description, epilog=Epilog)
    parser.add_argument("FILE_IN", help="Input samplesheet file.")
    parser.add_argument("FILE_OUT", help="Output file.")
    return parser.parse_args(args)


def make_dir(path):
    if len(path) > 0:
        try:
            os.makedirs(path)
        except OSError as exception:
            if exception.errno != errno.EEXIST:
                raise exception


def print_error(error, context="Line", context_str=""):
    error_str = "ERROR: Please check samplesheet -> {}".format(error)
    if context != "" and context_str != "":
        error_str = "ERROR: Please check samplesheet -> {}\n{}: '{}'".format(
            error, context.strip(), context_str.strip()
        )
    print(error_str)
    sys.exit(1)

### Check files listed in sample sheet for correct FastQ nomenclature and format ###

def check_fastqs(sample_mapping_dict):
    '''
    input:
        sample_mapping_dict - dictionary of samples with sample names as keys and lists of read files as values (dictionary)
    output:
        results - standard output from each file in input directory with file name (string) as key and result code (int) as value (dictionary)
    '''
    filenames = []
    for sample in sample_mapping_dict.values():
        filenames += sample[0]

    cmds_list = [['check_fastq.sh','-i',file] for file in filenames]
    procs_list = [Popen(cmd, stdout=PIPE, stderr=STDOUT) for cmd in cmds_list]
    results = dict()
    for proc in procs_list:
        proc.wait()
        stdout, stderr = proc.communicate()
        out = stdout.decode().split(',')
        results[os.path.basename(out[1])] = int(out[0])
    return results


### Parse standard output from check_fastq.sh script, determine passing/failing files, and output results ###

def output_results(results):
    '''
    input:
        results - standard output from each file in sample sheet with file name (string) as key and result code (int) as value (dictionary)
    '''
    if sum(results.values()) == 0:
        print('\nAll FASTQ files passed format & nomenclature check\n')
    else:
        for file in results:
            if results[file] == 1:
                print("\nError: file {} is not a FASTQ file or does not follow the accepted nomenclature, sample sheet should contain ONLY appropriately named FASTQ files\n".format(file))
            elif results[file] == 2:
                print("\nError: file {} is not a valid FASTQ file, check file contents\n".format(file))
            elif results[file] == 3:
                print("\nError: file {} is too large (>1GB), please check the documentation for supported sequencers and downsample if needed\n".format(file))
        print('\nTerminating Run\n')
        sys.exit(1) 

def check_samplesheet(file_in, file_out):
    """
    This function checks that the samplesheet follows the following structure:

    sample,fastq_1,fastq_2
    SAMPLE_PE,SAMPLE_PE_RUN1_1.fastq.gz,SAMPLE_PE_RUN1_2.fastq.gz
    SAMPLE_PE,SAMPLE_PE_RUN2_1.fastq.gz,SAMPLE_PE_RUN2_2.fastq.gz

    For an example see:

    """

    sample_mapping_dict = {}
    with open(file_in, "r") as fin:
        ## Check header
        MIN_COLS = 2
        HEADER = ["sample", "fastq_1", "fastq_2"]
        header = [x.strip('"') for x in fin.readline().strip().split(",")]
        if header[: len(HEADER)] != HEADER:
            print("ERROR: Please check samplesheet header -> {} != {}".format(",".join(header), ",".join(HEADER)))
            sys.exit(1)

        ## Check sample entries
        for line in fin:
            lspl = [x.strip().strip('"') for x in line.strip().split(",")]

            # Check valid number of columns per row
            if len(lspl) < len(HEADER):
                print_error(
                    "Invalid number of columns (minimum = {})!".format(len(HEADER)),
                    "Line",
                    line,
                )
            num_cols = len([x for x in lspl if x])
            if num_cols < MIN_COLS:
                print_error(
                    "Invalid number of populated columns (minimum = {})!".format(MIN_COLS),
                    "Line",
                    line,
                )

            ## Check sample name entries
            sample, fastq_1, fastq_2 = lspl[: len(HEADER)]
            if sample.find(" ") != -1:
                print(f"WARNING: Spaces have been replaced by underscores for sample: {sample}")
                sample = sample.replace(" ", "_")
            if not sample:
                print_error("Sample entry has not been specified!", "Line", line)

            ## Check FastQ file extension
            for fastq in [fastq_1, fastq_2]:
                if fastq:
                    if fastq.find(" ") != -1:
                        print_error("FastQ file contains spaces!", "Line", line)
                    if not fastq.endswith(".fastq.gz") and not fastq.endswith(".fq.gz"):
                        print_error(
                            "FastQ file does not have extension '.fastq.gz' or '.fq.gz'!",
                            "Line",
                            line,
                        )

            sample_info = []  ## [fastq_1, fastq_2]
            if sample and fastq_1 and fastq_2:  ## Paired-end short reads
                sample_info = [fastq_1, fastq_2]
            else:
                print_error("Invalid combination of columns provided!", "Line", line)

            ## Create sample mapping dictionary = { sample: [ fastq_1, fastq_2 ] }
            if sample not in sample_mapping_dict:
                sample_mapping_dict[sample] = [sample_info]
            else:
                if sample_info in sample_mapping_dict[sample]:
                    print_error("Samplesheet contains duplicate rows!", "Line", line)
                else:
                    sample_mapping_dict[sample].append(sample_info)
        
        ## Check that FastQ files are valid
        results = check_fastqs(sample_mapping_dict)
        output_results(results)

    ## Write validated samplesheet with appropriate columns
    if len(sample_mapping_dict) > 0:
        out_dir = os.path.dirname(file_out)
        make_dir(out_dir)
        with open(file_out, "w") as fout:
            fout.write(",".join(["sample", "fastq_1", "fastq_2"]) + "\n")
            for sample in sorted(sample_mapping_dict.keys()):
                ## Check that multiple runs of the same sample are of the same datatype
                if not all(x[0] == sample_mapping_dict[sample][0][0] for x in sample_mapping_dict[sample]):
                    print_error(
                        "Multiple runs of a sample must be of the same datatype!",
                        "Sample: {}".format(sample),
                    )

                for idx, val in enumerate(sample_mapping_dict[sample]):
                    fout.write(",".join([sample]+val) + "\n")
    else:
        print_error("No entries to process!", "Samplesheet: {}".format(file_in))

def main(args=None):
    args = parse_args(args)

    check_samplesheet(args.FILE_IN, args.FILE_OUT)


if __name__ == "__main__":
    sys.exit(main())