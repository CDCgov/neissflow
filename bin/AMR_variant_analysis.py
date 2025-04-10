#!/usr/bin/env python3

import argparse
import subprocess
import re
import os

### Get columns + column order for AMR report (per Sandeep's request) ###
def get_columns(column_file):
    '''
    input:
        column_file - path of file with columns in correct order for report (string)
    output:
        columns - columns in correct order for report (list)
    '''
    columns = []
    with open(column_file) as file:
        for line in file:
            columns.append(line.strip())
    return columns

### Read AMR_defaults.tsv into a dictionary ###
def get_AMR_defaults(defaults):
    '''
    input:
        defaults - path of file with AMR gene position default AA/Nucs 
    output:
        hgt_defaults - locuses of AMR genes that are (mostly) NOT present in FA19 / horizontally transferred genes with positions of interest as keys (nested dictionary)
        WG_Defaults - contains defaults for positions in AMR genes that are present in FA19 with positions of interest as keys (nested dictionary)
        mtrR_promoter - contains nucleotide positions as keys and default nucleotides as values for the mtrR promoter (dictionary)
    '''
    hgt_defaults = {}
    WG_defaults = {}
    mtrR_promoter = {}
    with open(defaults) as file: 
        count = 0
        for line in file:
            if count > 0:
                fields = line.strip().split('\t')
                if fields[2] == "CP012026": #Locus for FA19
                    if fields[0] == "mtrR promoter": #this promoter contains 5 positions, won't work well in WG dictionary
                        positions=fields[3].split(',')
                        for i in range(len(positions)):
                            mtrR_promoter[positions[i]] = fields[5][i]
                    else:
                        WG_defaults[fields[0]] = {"Gene":fields[1], "Locus":fields[2], "Nucleotide Position":fields[3], "AA Position":fields[4], "Default":fields[5]}
                else:
                    hgt_defaults[fields[0]] = {"Gene":fields[1], "Locus":fields[2], "Nucleotide Position":fields[3], "AA Position":fields[4], "Default":fields[5]}
            count += 1
    return hgt_defaults, WG_defaults, mtrR_promoter

### grep line from tab separated VCF file that matches the position we're looking for (if it exists) ###
def run_grep(pattern,file):
    '''
    input:
        pattern - regex to match line we're looking for (string)
        file - path of tab separated version of VCF file (string)
    output:
        bool - True if line matching regex is found False if there is no match
        variant - list version of line matching regex (list) 
    '''
    proc = subprocess.Popen(['grep','-Po',pattern,file],stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    proc.wait()
    stdout, stderr = proc.communicate()
    variant = stdout.decode().split('\t')
    if len(variant) == 1:
        return False,variant
    return True,variant

### Create tab separated VCF file with just relevant variants ###
def get_AMR_variants(hgt_calls,wg_calls,WG_defaults,sample,hgt_genes,mtrR_promoter,out):
    '''
    input:
        hgt_calls - path to tab delimited vcf file for AMR genes that are (mostly) NOT present in FA19 / horizontally transferred genes (string)
        wg_calls - path to tab delimited vcf file for whole genome (string)
        WG_Defaults - contains defaults for positions in AMR genes that are present in FA19 with positions of interest as keys (nested dictionary)
        sample - name of sample (string)
        hgt_genes - locuses of AMR genes that are (mostly) NOT present in FA19 / horizontally transferred genes as keys and gene names as values (dictionary)
        out - path of output directory (string)
    output:
        file - name of tab separated vcf file with just relevant AMR genes (string)
    '''
    file = os.path.join(out,sample+'_amr_vcf.tsv')
    if not os.path.isdir(out):
        os.mkdir(out)
    out = open(file,'w')
    with open(hgt_calls) as f:
        count = 0
        for line in f:
            if count == 0:
                out.write(line)
            else:
                fields = line.split('\t')
                gene = hgt_genes[fields[0]]
                fields[12] = gene
                out.write('\t'.join(fields))
            count += 1
    out.close()

    Genes = []
    cmds_list = []
    for position in WG_defaults:
        Genes.append(WG_defaults[position]['Gene'])
        if WG_defaults[position]['Nucleotide Position'] != 'NA':
            cmds_list.append(['grep',WG_defaults[position]['Nucleotide Position'],wg_calls])
    Genes=set(Genes)
    cmds_list.extend([['grep',gene,wg_calls] for gene in Genes])
    cmds_list.append(['grep','mrcA',wg_calls]) #mrcA is ponA 
    cmds_list.append(['grep','mexB',wg_calls]) #mexB is mtrD 
    cmds_list.extend([['grep',pos,wg_calls] for pos in mtrR_promoter])

    out = open(file,'a')
    procs_list = [subprocess.Popen(cmd, stdout=out, stderr=subprocess.STDOUT) for cmd in cmds_list]
    for proc in procs_list: 
        proc.wait()
    out.close()

    return file

### Check if snippy identified an insertion resulting in a duplicate aspartic acid at amino acid position 345 (duplicate is at position 346) in penA ###
def penA_D345ins(WG_defaults,gene,field,file):
    '''
    input:
        WG_defaults - contains defaults for positions in AMR genes that are present in FA19 with positions of interest as keys (nested dictionary)
        gene - "penA" (string)
        field - "penA D345ins" (string)
        file - name of tab separated vcf file with just relevant AMR genes (string)
    output:
        bool - True if this mutation is present False if it is not (string)
    '''
    pattern = '.*[^\S]+[0-9]+[^\S]+ins.*[0-9]+\/[0-9]+[^\S]+' + WG_defaults[field]["AA Position"] + '\/[0-9]+.*' + gene + '.*' 
    found,variant = run_grep(pattern,file)
    if found:
        result = variant[10].split(' ')[-1].split(WG_defaults[field]["AA Position"]) #parse resulting AA from "EFFECT" column
        if len(result) == 2 and len(result[1]) == 3:
            aa = result[1]
        else:
            return 'False' 
        return str(aa == 'dup') #snippy calls it as "dup" as it is a duplicate of the Asp at position 345
    return 'False'

### Check all whole genome positions with default values to see if mutations appear at those positions ###
def get_FA19_calls(WG_defaults,file,AA):
    '''
    input:
        WG_defaults - contains defaults for positions in AMR genes that are present in FA19 with positions of interest as keys (nested dictionary)
        file - name of tab separated vcf file with just relevant AMR genes (string)
        AA - amino acid multi letter code as keys and single letter code as values (dictionary)
    output:
        results - stores variants for sample with positions as keys and found variants or defaults as values (dictionary)
    '''
    results = {}    
    for field in WG_defaults.keys():
        if field != 'penA D345ins':
            if WG_defaults[field]["Nucleotide Position"] != 'NA':
                pattern = '.*[^\S]+' + WG_defaults[field]["Nucleotide Position"] + '[^\S]+.*'
                found,variant = run_grep(pattern,file)
                if found and len(variant[4]) == 1:
                    results[field] = variant[4]
                else: 
                    results[field] = WG_defaults[field]["Default"]
            else:
                if WG_defaults[field]["Gene"] == 'ponA':
                    pattern = '.*p(.)[a-zA-Z]+' + WG_defaults[field]["AA Position"] + '[a-zA-Z]+.*' + 'mrcA' + '.*' #ponA is annotated as mrcA in FA19
                elif WG_defaults[field]["Gene"] == 'mtrD':
                    pattern = '.*p(.)[a-zA-Z]+' + WG_defaults[field]["AA Position"] + '[a-zA-Z]+.*' + 'mexB' + '.*' #mtrD is annotated as mexB in FA19
                else: pattern = '.*p(.)[a-zA-Z]+' + WG_defaults[field]["AA Position"] + '[a-zA-Z]+.*' + WG_defaults[field]["Gene"] + '.*' 
                found,variant = run_grep(pattern,file)
                if found:
                    result = variant[10].split(' ')[-1].split(WG_defaults[field]["AA Position"]) #parse resulting AA from "EFFECT" column
                    if len(result) == 2 and len(result[1]) == 3:
                        aa = result[1]
                        results[field] = AA[aa]
                    elif len(result) == 2 and len(result[1]) > 3: #deal with complex mutations that START at the AA position of interest (takes the first AA change in the complex mutation)
                        aa = ''.join(list(result[1])[0:3])
                        results[field] = AA[aa]
                    else:
                        results[field] = WG_defaults[field]["Default"] 
                else: 
                    results[field] = WG_defaults[field]["Default"]
        else: results[field] = penA_D345ins(WG_defaults,WG_defaults[field]["Gene"],field,file)
    return results

### Check if mutations were found at the mtrR promoter positions (Matthew only wants 1 value reported for 5 positions since there is "usually only one mutation at most" so that's what we're doing) ###
def get_mtrR_promoter(mtrR_promoter,file,results):
    '''
    input:
        mtrR_promoter - contains nucleotide positions as keys and default nucleotides as values for the mtrR promoter (dictionary)
        file - name of tab separated vcf file with just relevant AMR genes (string)
        results - stores variants for sample with positions as keys and found variants or defaults as values (dictionary)
    output:
        results - results dictionary with 'mtrR promoter' key and nucleotide values added (dictionary)
    '''
    call = ""
    for nuc_pos in mtrR_promoter.keys():
        pattern = '.*[^\S]+' + nuc_pos + '[^\S]+.*'
        found,variant = run_grep(pattern,file)
        if found:
            call += variant[4]
        else:
            call += mtrR_promoter[nuc_pos]
    results['mtrR promoter'] = call
    return results

### Check all HGT / extra positions with default values to see if mutations appear at those positions ###
def get_hgt_calls(hgt_calls,hgt_defaults,results):
    '''
    input:
        hgt_calls - path to tab delimited vcf file for AMR genes that are (mostly) NOT present in FA19 / horizontally transferred genes (string)
        hgt_defaults - locuses of AMR genes that are (mostly) NOT present in FA19 / horizontally transferred genes with positions of interest as keys (nested dictionary)
        results - stores variants for sample with positions as keys and found variants or defaults as values (dictionary)
    output:
        results - results dictionary with hgt / extra AMR gene keys and values added (dictionary)
    '''
    for field in hgt_defaults.keys():
        pattern = '^' + hgt_defaults[field]["Locus"] + '[^\S]+' + hgt_defaults[field]["Nucleotide Position"] + '[^\S]+.*' 
        found,variant = run_grep(pattern,hgt_calls)
        if found:
            if re.search('freq',field) == None and len(variant[4]) == 1:
                results[field] = variant[4]
            else:
                evid = variant[5].split(' ') #use "EVIDENCE" to get SNP frequency in sample
                counts = []
                for nuc in evid:
                    print(variant,evid,nuc)
                    counts.append(int(nuc.split(':')[1]))
                freq = counts[0]/sum(counts)
                results[field] = str(freq)
        else: 
            results[field] = hgt_defaults[field]["Default"]
    return results

### Check if snippy identified any insertions in the rplV gene ###
def rplV_ins(results,file):
    '''
    input:
        results - stores variants for sample with positions as keys and found variants or defaults as values (dictionary)
        file - name of tab separated vcf file with just relevant AMR genes (string)
    output:
        results - results dictionary with 'rplV ins' key and string cast bool value (True if insertion found False if not)
    '''
    pattern = '.*[^\S]+[0-9]+[^\S]+ins.*rplV.*'
    found,variant = run_grep(pattern,file)
    results['rplV ins'] = str(found)
    return results

### Check vcf as far as 5 AA positions or 15 nucleotide positions back for complex mutations ###
def check_vcf(poi,file,lookback,AA):
    '''
    input: 
        poi - position of interest dictionary with "Gene", "Locus", "Nucleotide Position", "AA Position", and "Default" as keys with the corresponding information as values (dictionary)
        file - name of tab separated vcf file with just relevant AMR genes (string)
        lookback - number of positions to look back for considering complex mutations (int)
        AA - amino acid multi letter code as keys and single letter code as values (dictionary)
    output:
        not_found - True if no complex variants impacting the point of interest are found (bool) 
        variant - amino acid or nucleotide found at position of interest within complex mutation
    '''
    not_found = True 
    variant = ''
    for i in range(1,lookback+1):

        if poi['AA Position'] != 'NA':
            position = str(int(poi['AA Position']) - i)
            if poi['Gene'] == 'ponA':
                pattern = '.*complex.*.*p(.)[a-zA-Z]+' + position + '[a-zA-Z]+.*' + 'mrcA' + '.*' #ponA is annotated as mrcA in FA19
            elif poi['Gene'] == 'mtrD':
                 pattern = '.*complex.*.*p(.)[a-zA-Z]+' + position + '[a-zA-Z]+.*' + 'mexB' + '.*' #mtrD is annotated as mexB in FA19
            else: pattern = '.*complex.*.*p(.)[a-zA-Z]+' + position + '[a-zA-Z]+.*' + poi['Gene'] + '.*' 
        else: 
            position = str(int(poi['Nucleotide Position']) - i)
            pattern = '^' + poi["Locus"] + '[^\S]+' + position + '[^\S]+complex.*' 

        found,variant = run_grep(pattern,file)
        if found:
            if poi['AA Position'] != 'NA':
                AA_list = variant[10].split(' ')[-1].split(position) #parse resulting AA from "EFFECT" column 
                num_aa = i*3
                if len(AA_list[1]) > num_aa: #check if complex variant reaches position of interest
                    aa = ''.join(list(AA_list[1])[num_aa:(num_aa+3)])
                    variant = AA[aa]
                    not_found = False 
            else:
                nuc_list = list(variant[4])
                if len(nuc_list) > i: #check if complex variant reaches position of interest
                    variant = nuc_list[i]
                    not_found = False
            break #if the variant does not reach the point of interest no further away variants will and the point of interest will stay set to wild type default, so we exit either way

    return not_found,variant
    

### Check if snippy called complex mutations impacting positions of interest ###
def check_complex(results,file,hgt_defaults,WG_defaults,AA):
    '''
    input:
        results - stores variants for sample with positions as keys and found variants or defaults as values (dictionary)
        file - name of tab separated vcf file with just relevant AMR genes (string)
        hgt_defaults - locuses of AMR genes that are (mostly) NOT present in FA19 / horizontally transferred genes with positions of interest as keys (nested dictionary)
        WG_defaults - contains defaults for positions in AMR genes that are present in FA19 with positions of interest as keys (nested dictionary)
        AA - amino acid multi letter code as keys and single letter code as values (dictionary)
    output:
        results - results dictionary updated to include mutations at positions of interest due to complex mutations
    '''
    not_found = True

    for result in results:

        if result in hgt_defaults and re.search('freq',result) == None:
            if results[result] == hgt_defaults[result]['Default']:
                if hgt_defaults[result]['Nucleotide Position'] != 'NA':
                    not_found,variant = check_vcf(hgt_defaults[result],file,30,AA)
                else: not_found,variant = check_vcf(hgt_defaults[result],file,10,AA)

        elif result in WG_defaults and result != 'penA D345ins':
            if results[result] == WG_defaults[result]['Default']:
                if WG_defaults[result]['Nucleotide Position'] != 'NA':
                    not_found,variant = check_vcf(WG_defaults[result],file,30,AA)
                else: not_found,variant = check_vcf(WG_defaults[result],file,10,AA)

        if not not_found: #sorry for the double neg
            results[result] = variant
            not_found = True #reset this for the next position of interest

    return results

### Parse gene depth file determine depth at position of interest ###
def get_depth(file, poi):
    '''
    input:
        file - file name of file containing per position depth for gene the position of interest is in (string)
        poi - position of interest dictionary with "Gene", "Locus", "Nucleotide Position", "AA Position", and "Default" as keys with the corresponding information as values (dictionary)
    output:
        found - True if the position was checked and a depth was determined, False otherwise (bool)
        depth - depth at the position of interest (float)
    '''
    if poi['Nucleotide Position'] != 'NA':
        with open(file) as f:
            for line in f:
                l = line.split("\t")
                if int(l[1]) == int(poi['Nucleotide Position']):
                    return True,float(l[2])
        f.close()
    else:
        position = int(poi['AA Position'])*3
        depth = 0
        with open(file) as f:
            count = 0
            first = True
            for line in f:
                l = line.split("\t")
                if first:
                    start = int(l[1]) #need to use this to find correct nucleotide position
                    first = False
                if int(l[1]) == start+position+count:
                    depth += int(l[2])
                    count += 1 
                if count == 3: #we got all the nucleotide positions for the AA of interest
                    return True,depth/3       
        f.close()
    return False,0 #If a position and gene designation don't agree we don't get stuck (not an issue with current pois)

### Get correct gene file and call get depth function ###
def check_position(files,poi):
    '''
    input:
        files - files containing per position depth for each of the FA19 genes (not including 16S and 23S since those have multiple copies & very high coverage) (list)
        poi - position of interest dictionary with "Gene", "Locus", "Nucleotide Position", "AA Position", and "Default" as keys with the corresponding information as values (dictionary)
    output:
        checked - True if the position was checked and a depth was determined, False otherwise (bool)
        depth - depth at the position of interest (float)
    '''
    depth = 0 
    checked = False
    for file in files:
        if (poi['Gene'] + "_depth.txt") in file:
            checked,depth = get_depth(file,poi)
            return checked,depth
    return checked,depth

### Check depth at all mtrR positions ###
def mtrR_promoter_depth(mtrR_promoter,files):
    '''
    input:
        mtrR_promoter - contains nucleotide positions as keys and default nucleotides as values for the mtrR promoter (dictionary)
        files - files containing per position depth for each of the FA19 genes (not including 16S and 23S since those have multiple copies & very high coverage) (list)
    output:
        depths - depth of coverage at each of the mtrR promoter sites (list)
    '''
    depths = []
    for file in files:
        if ('mtrR-CDEprom' + "_depth.txt") in file:
            for nuc in mtrR_promoter:
                with open(file) as f:
                    for line in f:
                        l = line.split("\t")
                        if int(l[1]) == int(nuc):
                            depths.append(float(l[2]))
            break
    f.close()
    return depths

### Determine if position of interest has enough coverage to make a determination or not ###
def check_depths(files,results,WG_defaults,mtrR_promoter):
    '''
    input:
        files - files containing per position depth for each of the FA19 genes (not including 16S and 23S since those have multiple copies & very high coverage) (list)
        results - stores variants for sample with positions as keys and found variants or defaults as values (dictionary)
        WG_defaults - contains defaults for positions in AMR genes that are present in FA19 with positions of interest as keys (nested dictionary)
        mtrR_promoter - contains nucleotide positions as keys and default nucleotides as values for the mtrR promoter (dictionary)
    output:
        results - results dictionary updated with some values as "NF" if the position of interest did not have enough coverage (>10x) to call variant or wild type (nested dictionary)
    '''
    for result in results:
        if result in WG_defaults and result != 'penA D345ins':
            if results[result] == WG_defaults[result]['Default']:
                checked, depth = check_position(files,WG_defaults[result])
                if depth <= 10 and checked:
                    results[result] = 'NF' #not enough depth of coverage at position, change to not found
    
    depths = mtrR_promoter_depth(mtrR_promoter,files)

    nucs = list(results['mtrR promoter'])
    low_cov = False
    for i in range(len(depths)):
        if nucs[i] == "A" and depths[i] <= 10:
            nucs[i] = "NF"
            low_cov = True
    if low_cov:
        results['mtrR promoter'] = ''.join(nucs)
        
    return results

### Check if snippy identified premature stop ###
def premature_stop(gene,results,file,field,default):
    '''
    input:
        gene - gene to check if there is a premature stop for (string)
        results - stores variants for sample with positions as keys and found variants or defaults as values (dictionary)
        file - name of tab separated vcf file with just relevant AMR genes (string)
        field - name of parameter in report
        default - default bool for parameter
    output:
        results - results dictionary with field key and string cast bool value (True if premature stop found False if not)
    '''
    pattern = '.*stop_gained.*' + gene + '.*'
    found,variant = run_grep(pattern,file)
    if (found and not default) or (not found and not default): #deal with the reporting subject discrepancy
        results[field] = str(found)
    elif (not found and default) or (found and default):
        results[field] = str(not found)
    return results


### Check average depth of gene to determine if it is present in the sample ###
def check_presence(cov,gene):
    '''
    input:
        cov - average depth for all AMR genes with genes as keys and average depths as values (dictionary)
        gene - gene to check the presence of in the sample (string)
    output:
        bool - True if average depth of the gene is >= 2 and False if it is not (string)
    '''
    return str(float(cov[gene]) >= 2) #threshold of 2 used (determined by Matthew)

### Check presence of horizontally transferred genes in the sample ###
def htg(results,coverage_file):
    '''
    input:
        results - stores variants for sample with positions as keys and found variants or defaults as values (dictionary)
        coverage_file - path of file generated for sample with average depths for AMR genes, determined by Samtools depth (string)
    output:
        results - results dictionary with '<HGT gene> present' keys and string cast bool value (True if present False if not)
    '''
    lines = []
    with open(coverage_file) as file:
        for line in file:
            lines.append(line.strip().split('\t'))

    cov = {}
    for i in range(1,len(lines[0])):
        cov[lines[0][i]] = lines[1][i]

    results['blaTEM present'] = check_presence(cov,'blaTEM')
    results['tetM present'] = check_presence(cov,'TetM-partial')
    results['ermB present'] = check_presence(cov,'ermB')
    results['ermC present'] = check_presence(cov,'ermC')
    results['ermF present'] = check_presence(cov,'ermF')
    results['mefA present'] = check_presence(cov,'mefA')
    return results

### Write AMR report file for sample using results dictionary ###
def write_amr_report(sample,results,out,columns):
    '''
    input:
        sample - name of sample (string)
        results - stores variants for sample with positions as keys and found variants or defaults as values (dictionary)
        out - path of output directory (string)
        columns - columns for report in the correct order (list)
    '''
    file = os.path.join(out,sample+'_variant_report.tsv')
    out = open(file,'w')
    out.write('Sample')
    for field in columns:
        out.write('\t'+field)
    out.write('\n'+sample)
    for field in columns:
        out.write('\t'+results[field])
    out.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
                        prog='python3 AMR_variant_analysis.py',
                        description='This program performs the variant analysis for GC AMR genes based on Snippy output')
        
    parser.add_argument('-w','--whole_genome', type=str, required=True, help='Full path of TAB delimited variant output of whole genome from Snippy')
    parser.add_argument('-t','--hgt', type=str, required=True, help='Full path of TAB delimited variant output of just horizonally transferred genes from Snippy')
    parser.add_argument('-c','--cov', type=str, required=True, help='Full path of per AMR gene coverage (average depth) report for input sample')
    parser.add_argument('-s','--depths', type=str, nargs=17, required=True, help='paths of files containing per position depths of genes in FA19')
    parser.add_argument('-n','--name', type=str, required=True, help='Sample name')
    parser.add_argument('-o','--out_path', type=str, required=True, help='path of output directory')
    parser.add_argument('-d','--defaults', type=str, required=True, help='path of default AMR genes file')
    parser.add_argument('-f','--fields', type=str, required=True, help='path of column order file')
    
        
    args = parser.parse_args()

    wg_calls = args.whole_genome
    hgt_calls = args.hgt
    coverage_file = args.cov
    files = args.depths
    sample = args.name
    out = args.out_path
    defaults = args.defaults
    column_file = args.fields

    hgt_genes={"X67293":'23SrRNA', "AB551787":'blaTEM',"EU048317":'ermB',"AE002098":'ermC', "NG_047825":'ermF', "16S-CP012026":'FA19_16SrRNA', "AY319932":'mefA', "NC_003112":'Nm_sodC', "AF116348":'TetM-partial'}
    AA = {'Ala':'A','Arg':'R','Asn':'N','Asp':'D','Cys':'C','Glu':'E','Gln':'Q','Gly':'G','His':'H','Ile':'I','Leu':'L','Lys':'K','Met':'M','Phe':'F','Pro':'P','Ser':'S','Thr':'T','Trp':'W','Tyr':'Y','Val':'V'}

    hgt_defaults, WG_defaults, mtrR_promoter = get_AMR_defaults(defaults)
    columns = get_columns(column_file)
    file = get_AMR_variants(hgt_calls,wg_calls,WG_defaults,sample,hgt_genes,mtrR_promoter,out)
    results = get_FA19_calls(WG_defaults,file,AA)
    results = get_hgt_calls(hgt_calls,hgt_defaults,results)
    results = check_complex(results,file,hgt_defaults,WG_defaults,AA)
    results = get_mtrR_promoter(mtrR_promoter,file,results)
    results = check_depths(files,results,WG_defaults,mtrR_promoter)
    results = rplV_ins(results,file)
    results = premature_stop('pilQ',results,file,'pilQ full length',True)
    results = premature_stop('mtrR',results,file,'mtrR premature stop',False)
    results = htg(results,coverage_file)
    write_amr_report(sample,results,out,columns)