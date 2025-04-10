#!/usr/bin/env python

import argparse
import collections
import numpy as np
import csv

class ConnectedComponents:
    '''
    implement disjoint set union (DSU) to identify
    connected components in the resulting graph of 
    isolates with SNP distances of <20
    '''
    ### Merge 2 components ###
    def merge(self,parent,x):
        if parent[x] == x:
            return x 
        return self.merge(parent,parent[x])
    
    ### find ccs ###
    def connectedComponents(self,n,edges,names,matrix):
        '''
        input:
            n - number of nodes in graph (int)
            edges - edges in undirected graph (list of lists)
            names - isolate names (list of strings)
            matrix - 2D array containing SNP dists (numpy array of ints)
        output:
            num - number of connected components
        '''
        parent = [i for i in range(n)] #store parents of each node

        #set parent of each node
        for x in edges:
            parent[self.merge(parent,x[0])] = self.merge(parent,x[1])
        
        #merge components
        for i in range(n):
            parent[i] = self.merge(parent, parent[i])

        #store parent and its ccs
        m = collections.defaultdict(list)
        for i in range(n):
            m[parent[i]].append(i)
        
        #print ccs and SNP dists within ccs with size >1
        num = 0 
        for comp in m.items():
            l = comp[1]
            if len(l) > 1:
                num += 1
                print(" ".join([names[x]+" "+str(matrix[l,x]) for x in l]))

        return num

### get matrix of SNP dists from TSV file ###
def get_matrix(file):
    '''
    input:
        file - path to SNP dists TSV file (string)
    output:
        matrix - 2D array containing SNP dists (numpy array of ints)
        names - isolate names (list of strings)
    '''
    with open(file) as f:
        names = f.readline().split('\t')
    
    ncols = len(names)

    names.pop(0) #remove first index since that isn't an isolate name
    matrix = np.loadtxt(file,dtype=int,delimiter='\t',skiprows=1,usecols=range(1,ncols))
    return matrix, names

### construct graph from SNP dists matrix from isolates with a SNP distance of < dist ###
def get_edges(matrix,dist):
    '''
    input:
        matrix - 2D array containing SNP dists (numpy array of ints)
        dist   - SNP distance to use for constuction graph
    output:
        edges - edges for undirected graph of isolates with SNP dist of <30 sharing an edge (list of lists)
    '''
    edges = []
    for i in range(len(matrix)):
        for j in range(i):
            if matrix[i,j] < dist:
                edges.append([i,j])
    return edges

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
                        prog='python3 outbreak_detection.py',
                        description='This program checks for outbreaks based on the SNP distances matrix')
        
    parser.add_argument('-i','--input', type=str, required=True, help='Full path of input matrix TSV file')
    parser.add_argument('-d','--dist', type=int, required=True, help='SNP distance to use for constuction graph')

    args = parser.parse_args()

    file = args.input
    dist = args.dist

    matrix,names = get_matrix(file)
    edges = get_edges(matrix,dist)

    num = ConnectedComponents().connectedComponents(len(names),edges,names,matrix)
