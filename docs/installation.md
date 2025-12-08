# neissflow: Installation

## Introduction

This document overviews the setup process for neissflow, depending on how you plan to run the pipeline.

## Dependencies

1. [Nextflow](https://www.nextflow.io/docs/latest/install.html#install-page): this pipeline runs with version 24.10.5 and later
2. [Singularity](https://docs.sylabs.io/guides/3.0/user-guide/installation.html)
3. [Python](https://www.python.org/)
4. [rauth](https://rauth.readthedocs.io/en/latest/)
5. [BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi)
6. Local Mash sketch of RefSeq
   - Download [RefSeqSketchesDefaults.msh.gz](https://mash.readthedocs.io/en/latest/data.html)
   - Move it to a directory where it can be accessed by the pipeline
   - Decompress the sketch with the following command
   ```
   gunzip RefSeqSketchesDefaults.msh.gz
   ```
5. Local MLST database (install after cloning the repository with step 3)

## Cluster/Cloud/Local Installation

1. Clone or fork and clone the repository onto your system
2. Obtain the necessary configuration profiles to run on your system, your system administrator my have these or you can find some on [nf-core](https://nf-co.re/configs/). Use the profile(s) with one of the two options
   - Add the necessary configuration profile(s) to run the pipeline on your system to [conf/](../conf) and include these .config files in [nextflow.config](../nextflow.config)
   - Use the -c argument when running neissflow to include the configuration files ex:
     ```
     nextflow run neissflow/main.nf -profile singularity,<your profile> -c <your config>.config --input samplesheet.csv --outdir out/ --only_fastq
     ```
3. Use [BIGSdb_downloader](https://github.com/kjolley/BIGSdb_downloader) and [make_mlst_databases.sh](../assets/make_mlst_databases.sh) to download MLST alleles from PubMLST and make the neisseria mlst database.
   - Create or access your [PubMLST](https://pubmlst.org/bigsdb) account
   - Create an API Key through My Account -> API Keys
   - Clone the [BIGSdb_downloader](https://github.com/kjolley/BIGSdb_downloader) repository
   ```
   git clone https://github.com/kjolley/BIGSdb_downloader.git
   ```
   - Ensure you have [Python](https://www.python.org/) installed
   - Install [rauth](https://rauth.readthedocs.io/en/latest/)
   ```
   pip install rauth
   ```
   - Set up connection to BIGSdb (this is only active for an hour and this step will need to be repeated for any downloads to occur beyond 1 hour)
   ```
   python3 ./BIGSdb_downloader/bigsdb_downloader.py --key_name "API KEY NAME" --site PubMLST --db pubmlst_neisseria_seqdef --token_dir <DIR TO SAVE KEYS AND TOKENS TO> --setup
   ```
   The script will prompt you to do the following: 
   ``` 
   Enter client id:
   ```
   and 
   ```
   Enter client secret:
   ```
   Copy over this information for the API key you created from PubMLST.  
   Next it will prompt you with:
   ```
   Please log in using your user account at <LINK> using a web browser to obtain a verification code.
   ```
   Go to the provided link and authorize the use of your key, PubMLST will then provide you with the verification code. You will then be prompted to enter the verification code:
   ```
   Please enter verification code:
   ```
   Enter the code provided to you by PubMLST. This will allow for 1 hour of downloading from PubMLST (more than enough time to set up this database)
   - Ensure you have [BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi) installed
   - Run [make_mlst_databases.sh](../assets/make_mlst_databases.sh) (this script requires Python and rauth to run BIGSdb_downloader.py and BLAST+ to make the BLAST database)
   ```
   neissflow/assets/make_mlst_databases.sh -k "API KEY NAME" -r /home/kmorin/BIGSdb_downloader -p pubmlst/ -b blastdb/ -t <TOKEN DIR FROM SETUP>
   ```
   - Check that data has populated those directories & has read permissions
   - Using this database in neissflow:
     - Option 1: pass these paths to the pipeline as parameters each run with the arguments `--pubmlst` and `--blastdb`
     ```
     nextflow run neissflow/main.nf -profile singularity --input samplesheet.csv --outdir out/ --pubmlst pubmlst/ --blastdb blastdb/ --only_fastq
     ```
     - Option 2: change the default paths for `pubmlst` and `blastdb` variables in [nextflow.config](../nextflow.config)
   - If you are updating the database and not downloading it for the first time, ensure the pipeline runs and outputs the expected MLST types before deleting the old database files with the ".old" extension from both `pubmlst` and `blastdb` directories
4. Use the RefSeq Mash sketch in neissflow
   - Option 1: pass the path to RefSeqSketchesDefaults.msh to the pipeline as a parameter each run with the `--mash_db` argument
   - Option 2: change the default path for the `mash_db` parameter in [nextflow.config](../nextflow.config) to the path to RefSeqSketchesDefaults.msh
5. If you wish to test the pipeline with the test profile, you will need to change the paths of the test samples in [assets/samplesheet.csv](../assets/samplesheet.csv) to include the path to the repository on your system (ex: /repo path/assets/test_samples/sample_R1_001.fastq.gz)  
   Some sample output generated with these samples can also be found in `assets/sample_final_report.tsv` and `assets/sample_phylogeny_qc_report.tsv` for validating your test
6. Set the TMPDIR and TMP environment variables  
   On HPC systems the tmp directories on nodes can easily run out of space so it is best practice to set your temporary files to go to scratch. Neissflow contains modules that are configured to use these variables, so they will need to be set regardless of the system you are running on. Set these in the local or institutional profile you will be using to run neissflow with like the following example:

```
local {
    executor {
      name = 'local'
      queueSize = 6
    }
    process {
      memory = '16.GB'
      cpus = 1
      time = '12.h'
    }
    env {
      // TODO: Replace these paths with where you would like your temp files to go
      TMP = "/scratch/nextflow/tmp"
      TMPDIR = "/scratch/nextflow/tmp"
    }
  }
```

## Nextflow Tower setup

This pipeline can be deployed in Tower with minimal changes to the pipeline

1. Fork the repository and clone it onto the system that your instance of Tower runs on
2. Follow the installation instructions
3. Hardcode the full repo path in place of ${projectDir} in [nextflow.config](../nextflow.config) and [conf/test.config](../conf/test.config)
4. add, commit, and push these changes to the forked repository
5. follow the normal [steps](https://docs.seqera.io/platform/23.1/git/overview) of linking a remote git repository to Tower

## QC samples

The pipeline has a QC profile, which triggers control samples to run through the pipeline along with your main sample set (although they will be separated in the aggregated reports). These samples will not run through the phylogeny subworkflow since that is a combined analysis.

To incorporate control samples:

1. Make a samplesheet with paths to the control FASTQ file pairs
2. Edit [QC.config](../conf/QC.config) such that the controls parameter is set to the path to your control samplesheet
3. Include the QC profile when running neissflow ex:
   ```
   nextflow run neissflow/main.nf -profile singularity,QC --input samplesheet.csv --outdir out/ --only_fastq
   ```

## Updating the NGMASTER database

REDO THESE INSTRUCTIONS  

It is recommended that you update the NGMASTER database at a regular frequency as new alleles and STs are always being added to PubMLST for NG-MAST and NG-STAR

1. Download NGMASTER to your environment or within a conda environment
2. Update pubmlst NGMASTER database with:
   ```
   ngmaster --db neissflow/assets/alleledb/ --updatedb --assumeyes
   ```
   You can also move this database to another location in your system and use that path.
3. Run [assets/mlst-make_blast_db](../assets/mlst-make_blast_db) with the following command:
   ```
   $ ./mlst-make_blast_db neissflow/assets/alleledb/publmlst/ neissflow/assets/alleledb/blastdb/
   ```
   Again, if you opt to move this database elsewhere, use those paths.
4. Run neissflow using the test set
   ```
   nextflow run neissflow/main.nf -profile singularity,test --outdir out/
   ```

## Updating the mlst database

It is also recommended that you update the MLST database at a regular frequency. To do this follow the same steps as are outlined to download the database in step 3 of "Cluster/Cloud/Local installation"
