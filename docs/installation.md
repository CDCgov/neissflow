# neissflow: Installation

## Introduction

This document overviews the setup process for neissflow, depending on how you plan to run the pipeline.

## Dependencies 
1) [Nextflow](https://www.nextflow.io/docs/latest/install.html#install-page): this pipeline runs with version 23.10.0 and later  
2) [Singularity](https://docs.sylabs.io/guides/3.0/user-guide/installation.html)
3) [wget](https://niagads.scrollhelp.site/support/wget-linux-file-downloader-user-guide)
4) Local Mash sketch of RefSeq 
    - Download [RefSeqSketchesDefaults.msh.gz](https://mash.readthedocs.io/en/latest/data.html)
    - Move it to a directory where it can be accessed by the pipeline
    - Decompress the sketch with the following command
    ```
    $ gunzip RefSeqSketchesDefaults.msh.gz
    ```
5) Local MLST database (install after cloning the repository with step 3)

## Cluster/Cloud/Local Installation

1) Clone or fork and clone the repository onto your system
2) Obtain the necessary configuration profiles to run on your system, your system administrator my have these or you can find some on [nf-core](https://nf-co.re/configs/). Use the profile(s) with one of the two options
    - Add the necessary configuration profile(s) to run the pipeline on your system to [conf/](../conf) and include these .config files in [nextflow.config](../nextflow.config)  
    - Use the -c argument when running neissflow to include the configuration files ex:
        ```
        $ nextflow run neissflow/main.nf -profile singularity,<your profile> -c <your config>.config --input samplesheet.csv --outdir out/ --only_fastq
        ```
3) Download the [mlst](https://github.com/tseemann/mlst) database locally 
    - run [assets/mlst-download_pub_mlst](../assets/mlst-download_pub_mlst) with the following command:  
    ```
    $ ./mlst-download_pub_mlst -d /path_u_choose/pubmlst/
    ```
    - run [assets/mlst-make_blast_db](../assets/mlst-make_blast_db) with the following command:  
    ```
    $ ./mlst-make_blast_db /path_u_choose/pubmlst/ /path_u_choose/blastdb/
    ```
    - check that data has populated those directories & has read permissions
    - Using this database in neissflow:
        - Option 1: change the default paths for `pubmlst` and `blastdb` variables (the `blastdb` path specifically needs to be the path to mlst.fa) in [nextflow.config](../nextflow.config)
        - Option 2: pass these paths to the pipeline as parameters each run with the arguments `--pubmlst` and `--blastdb`
4) Use the RefSeq Mash sketch in neissflow
    - Option 1: change the default path for the `mash_db` parameter in [nextflow.config](../nextflow.config) to the path to RefSeqSketchesDefaults.msh
    - Option 2: pass the path to RefSeqSketchesDefaults.msh to the pipeline as a parameter each run with the `--mash_db` argument
5) If you wish to test the pipeline with the test profile, you will need to change the paths of the test samples in [assets/samplesheet.csv](../assets/samplesheet.csv) to include the path to the repository on your system (ex: /repo path/assets/test_samples/sample_R1_001.fastq.gz)  

## Nextflow Tower setup
This pipeline can be deployed in Tower with minimal changes to the pipeline  
1) Fork the repository and clone it onto the system that your instance of Tower runs on
2) Follow the installation instructions
3) Hardcode the full repo path in place of ${projectDir} in [nextflow.config](../nextflow.config) and [conf/test.config](../conf/test.config)
4) add, commit, and push these changes to the forked repository
5) follow the normal [steps](https://docs.seqera.io/platform/23.1/git/overview) of linking a remote git repository to Tower

## QC samples
The pipeline has a QC profile, which triggers control samples to run through the pipeline along with your main sample set (although they will be separated in the aggregated reports). These samples will not run through the phylogeny subworkflow since that is a combined analysis. 

To incorporate control samples:
1) Make a samplesheet with paths to the control FASTQ file pairs
2) Edit [QC.config](../conf/QC.config) such that the controls parameter is set to the path to your control samplesheet 
3) Include the QC profile when running neissflow ex: 
    ```
    $ nextflow run neissflow/main.nf -profile singularity,all,QC --input samplesheet.csv --outdir out/ --only_fastq 
    ```

## Updating the NGMASTER database
It is recommended that you update the NGMASTER database at a regular frequency as new alleles and STs are always being added to PubMLST for NG-MAST and NG-STAR
1) Download NGMASTER to your environment or within a conda environment
2) Update pubmlst NGMASTER database with: 
    ```
    $ ngmaster --db neissflow/assets/alleledb/ --updatedb --assumeyes
    ``` 
    You can also move this database to another location in your system and use that path.  
3) Run [assets/mlst-make_blast_db](../assets/mlst-make_blast_db) with the following command:  
    ```
    $ ./mlst-make_blast_db neissflow/assets/alleledb/publmlst/ neissflow/assets/alleledb/blastdb/
    ``` 
    Again, if you opt to move this database elsewhere, use those paths.
4) Run neissflow using the test set 
    ```
    $ nextflow run neissflow/main.nf -profile singularity,all,test --outdir <OUTDIR> --name <RUN NAME>
    ```

## Updating the mlst database
It is also recommended that you update the MLST database at a regular frequency. To do this follow the same steps as are outlined to download the database in step 3 of "Cluster/Cloud/Local installation"