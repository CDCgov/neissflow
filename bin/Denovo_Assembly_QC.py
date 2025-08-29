#!/usr/bin/env python3
##Author: Sandeep Joseph
##Note: would like to replace fully with QUAST + mean coverage check with samtools depth in future version -Kat

###IMPORT PYTHON MODULES  #####

import sys
import os
from Bio import SeqIO
import argparse
import gzip
import pandas as pd
import traceback
import re
from collections import Counter
import argparse

unambig = 'GATC'
unambig_set = set(unambig)
ambig_all_set = set('GATCRYWSMKHBVDN')
ambig_only_set = ambig_all_set.difference(unambig_set)

## Essential House keeping functions ###

format_guesser = { '.fasta' : 'fasta',
            '.fa'   : 'fasta',
            '.fna' : 'fasta'
            }

def guessFileFormat(filename):
    (base,ext) = os.path.splitext(filename)
    compressed = False
    if ext == '.gz':
        compressed = True
        (base,ext) = os.path.splitext(base)
    if ext in format_guesser:
        seq_format = format_guesser[ext]
    else:
        seq_format = None
    return seq_format, compressed
    

    
def printExceptionDetails(e,warn=None):
    if warn is None:
        warn='Exception'
    print("{}: {}".format(warn,e))
    print("at line:")
    traceback.print_tb(sys.exc_info()[2])
    traceback.print_exc()
    
def appendToFilename(filename,insert):
    (base, ext) = os.path.splitext(filename)
    if ext == '.gz':
        (base,ext2) = os.path.splitext(base)
        ext = ext2 + ext
    return base + insert + ext
    
def flexible_handle(filename,compression=False,mode='rt'):
    if compression:
        return gzip.open(filename,mode)
    else:
        return open(filename,mode)

def seqs_guess_and_parse2list(filename):
    seq = None
    seq_format, compressed = guessFileFormat(filename)
    if seq_format is not None:
        with flexible_handle(filename, compressed, 'rt') as seq_in:
            seq = [x for x in SeqIO.parse(seq_in,seq_format)]
    else:
        print("Cannot infer sequence format for file: " + filename)
    return seq
 

ContigHeaders = ['Contig_Name','Contig_Size','Coverage','Contig'] 

### Function to calculate the N50, N75 and N90 contig statistics ###

   
def N_stats(size_list, thresholds = None):
    if thresholds is None:
        thresholds = [50,75,90]
    assert max(thresholds) < 100
    assert min(thresholds) > 0
    sortedSizes = sorted(size_list,reverse=True)
    totalSize = sum(sortedSizes)
    threshold_sizes = {x: x*totalSize/100 for x in thresholds}
    cumulative = 0
    result = dict()
    for key in sorted(threshold_sizes.keys()): 
        size = threshold_sizes[key] 
        while cumulative < size: 
            x = sortedSizes.pop(0) 
            cumulative += x
        result[key] = x 
    return result

### Function parse out information from the fasta headers of spades contigs ####
    
def parse_contig_headers(c,oldVersion=False): 
    description_re = re.compile(r'^contig[0-9]+\s?len=[0-9]+\s?cov=[0-9]+.[0-9]?')
    seq_match = description_re.match(c.description)
    if not seq_match:
        raise ValueError ("Improper formatting for {}".format(c.description))
    
    if seq_match:
        info = seq_match.group(0).split(' ')
        length_text = info[1].split('=')[1]
        try:
            contig_length = int(length_text)
        except:
            print("Failure to parse contig length: "+length_text)
            contig_length = len(c)
            raise
        
        coverage_text = info[2].split('=')[1]
        try:
            coverage = float(coverage_text)
        except:
            print("Failure to parse coverage :"+coverage_text)    
            raise

        return pd.Series((c.id,contig_length,coverage,c),ContigHeaders)
    else: 
        print("not")
        return None
 
 
    
def ContigStats(contig_iterator,oldVersion=False):
    contig_records = []
    
    for contig in contig_iterator:
        this_record = parse_contig_headers(contig,oldVersion=oldVersion) 
       
        nuc_counts = Counter(str(contig.seq))
        ambig_upper_lower = set([i.lower() for i in ambig_only_set] + [i.upper() for i in ambig_only_set])
        ambig_counts = 0
        for item in ambig_upper_lower:
            if item in nuc_counts:
                ambig_counts += nuc_counts[item]
        
        unambig_upper_lower = set([i.lower() for i in unambig_set] + [i.upper() for i in unambig_set])
        unambig_counts = 0
        for item in unambig_upper_lower:
            if item in nuc_counts:
                unambig_counts += nuc_counts[item] 
        assert ambig_counts + unambig_counts == len(contig)      
        this_record['Ambiguous_nucleotides'] = ambig_counts
        
        
        contig_records.append(this_record)
   
    return pd.DataFrame(contig_records,dtype=str)

## Function to calculate the denovo assembly statistics ####
    
def denovoStats(filelist,out_file=None,save_details=False):
    assert isinstance(filelist,list)
    assert len(filelist) > 0
     
    if len(filelist) > 0:
        assemblyList = []
        for filename in filelist:
            genome_format,_ = guessFileFormat(filename)
            StatInfo = {'Filename':os.path.basename(filename).split('.')[0].strip('_contigs')}
            if genome_format is None:
                StatInfo['Note']='Could not identify genome format'  
            else:
                try:
                    contig_list = seqs_guess_and_parse2list(filename)                                       
                    if isinstance(contig_list,list) and len(contig_list) > 0:
                        contigFrame = ContigStats(contig_list) 
                        
                        assert len(contig_list) == len(contigFrame), "Not all contigs are in dataframe"  
                                        
                        StatInfo['Contig Count']=str(len(contig_list))
                        contigSizes = contigFrame['Contig_Size'].astype(int)
                        assemblySize = sum(contigSizes)                
                        StatInfo['Bases_In_Contigs'] = str(assemblySize)                   
                        largeContigs = contigSizes > 10000
                        StatInfo['Large_Contig_Count'] = str(sum(largeContigs))
                        StatInfo['Small_Contig_Count'] = str(sum(~largeContigs))
                        StatInfo['>500bp_Contig_Count'] = str(sum(contigSizes > 500))
                        StatInfo['Bases_In_Large_Contigs'] = str(sum(contigSizes[largeContigs]))
                        StatInfo['Bases_In_Small_Contigs'] = str(sum(contigSizes[~largeContigs]))
                        StatInfo['Fraction_Of_Contigs_That_Are_Large'] = '{:0.4f}'.format(sum(largeContigs)/len(contig_list))
                        emptyContigs = contigSizes == 0
                        if sum(emptyContigs) > 0:
                            print('\n#### WARNING #### EMPTY CONTIGS ########\n')                           
                            print('\n\t'.join(contigFrame[emptyContigs].Contig_Name.tolist()))
                            
                        if 'Coverage' in contigFrame.columns:
                            contigCoverage = contigFrame['Coverage'].astype(float) ##should be float
                            if len(contigCoverage[largeContigs]) > 0:
                                min_c = min(contigCoverage[largeContigs].astype(float))
                                StatInfo['Min_Coverage_Large_Contigs'] = str(min_c) 
                                max_c = max(contigCoverage[largeContigs].astype(float))
                                StatInfo['Max_Ratio_of_Coverage_Large_Contigs'] = '{:0.2f}'.format(max_c/min_c) 
                                lowC_contigs = contigFrame['Coverage'].astype(float) < (min_c / 2)
                                StatInfo['Low_Coverage_Contig_Count'] = sum(lowC_contigs)
                                StatInfo['Low_Coverage_Contig_Bases'] = sum(contigFrame.loc[lowC_contigs,'Contig_Size'].astype(int))
                            else:
                                StatInfo['Min_Coverage_Large_Contigs'] =  'N/A'
                                StatInfo['Max_Ratio_of_Coverage_Large_Contigs'] = 'N/A' 
                                StatInfo['Low_Coverage_Contig_Count'] = 'N/A'
                                StatInfo['Low_Coverage_Contig_Bases'] = 'N/A'                      
                            coverageProduct = contigFrame['Contig_Size'].astype(int) * contigFrame['Coverage'].astype(float)   
                            coverageProductSum = sum(coverageProduct)    
                            meanCoverage = coverageProductSum/assemblySize
                            StatInfo['Mean_Coverage'] = meanCoverage            
                            lowC_contigs = contigFrame['Coverage'].astype(float) < (meanCoverage / 2)
                            
                        
                        
                        ambigCounts = contigFrame['Ambiguous_nucleotides'].astype(int)
                        StatInfo['Ambiguous_nucleotides']=sum(ambigCounts)
                        
                               
                        
                        N_stat = N_stats(contigSizes.tolist(),thresholds=[50,75,90])
                        for n,size in N_stat.items():
                            header = "N{}".format(n)
                            StatInfo[header] = str(size)

                    else:
                        print("failed to parse file: "+filename)
                        StatInfo['Note'] = 'No sequences parsed from file'
                except Exception as e:
                    print("Warning: failed to assess file: " + filename)
                    print("Exception: {}".format(e))
                    raise
             
            if 'Bases_In_Contigs' not in StatInfo:
                StatInfo['Bases_In_Contigs'] = 0 
            if 'Contig Count' not in StatInfo:
                StatInfo['ContigCount'] = 0
            assemblyList.append(StatInfo)
        if len(assemblyList) > 0:
            print("Stats for {} assemblies.".format(len(assemblyList)))
            assFrame = pd.DataFrame(assemblyList)
            saveFrame = assFrame.set_index('Filename')
            if (out_file is not None):
                try:
                    saveFrame.to_csv(out_file,sep='\t')
                    
                except Exception as e:
                    print(saveFrame.to_csv(sep='\t'))
                    print()
                    print("Failed to print to target file {}. \nPrinted results to screen (above)".format(out_file))
                    printExceptionDetails(e)
        else:
            print("Failed to evaluate assemblies...")
            print("attempted to evaluate the following files:"+"\n".join(filelist))
    return assFrame
    
       
def main():
    
    
    parser = argparse.ArgumentParser(description='Generates summary denovo assembly statistics for shovill assemblies.')    
    parser.add_argument('fastas',nargs='+',help='FASTA assemblies to assess')
    parser.add_argument('--stat_output','-so',required=True,help='File to write summary denovo assembly statistics')
    parser.add_argument('--extension','-e',help="Limit analysis to files with the given suffix....fa., .fasta, .fna")
    
    
    args = parser.parse_args()
    #input_folder = os.path.abspath(args.directory)
    #assert os.path.isdir(input_folder),"Directory is invalid"
    
    out_file = args.stat_output

    #filelist = [os.path.join(input_folder,x) for x in os.listdir(input_folder)]
    #filelist = [x for x in filelist if os.path.isfile(x)]
    filelist = args.fastas
    print('Identified {} files.'.format(len(filelist)))
    if args.extension:
        filelist = [x for x in filelist if x.endswith(args.extension)]
        print('Focusing on {} files with the extension "{}"'.format(len(filelist),args.extension))

    denovoStats(filelist,out_file,save_details=False)
	

if __name__ == "__main__":
	main() 
    
    
    
    

