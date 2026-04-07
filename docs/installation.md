# neissflow: Installation

## Introduction

This document overviews the setup process for neissflow, depending on how you plan to run the pipeline.

## Dependencies
### Required
1. [Nextflow](https://www.nextflow.io/docs/latest/install.html#install-page): this pipeline runs with version 24.10.5 and later
2. [Singularity](https://docs.sylabs.io/guides/3.0/user-guide/installation.html)
3. Local Mash sketch of RefSeq
   - Download [RefSeqSketchesDefaults.msh.gz](https://gembox.cbcb.umd.edu/mash/RefSeqSketchesDefaults.msh.gz) (this can be downloaded with curl or wget as well as in your browser)
   - Move it to a directory where it can be accessed by the pipeline
   - Decompress the sketch with the following command
   ```
   gunzip RefSeqSketchesDefaults.msh.gz
   ```

### Optional
1. [Python](https://www.python.org/)
2. [rauth](https://rauth.readthedocs.io/en/latest/)
3. [BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi)

## Cluster/Cloud/Local Installation

1. Clone or fork and clone the repository onto your system
2. Obtain the necessary configuration profiles to run on your system, your system administrator my have these or you can find some on [nf-core](https://nf-co.re/configs/). Use the profile(s) with one of the two options
   - Add the necessary configuration profile(s) to run the pipeline on your system to [conf/](../conf) and include these .config files in [nextflow.config](../nextflow.config)
   - Use the -c argument when running neissflow to include the configuration files ex:
     ```
     nextflow run neissflow/main.nf -profile singularity,<your profile> -c <your config>.config --input samplesheet.csv --outdir out/ --only_fastq
     ```
3. Use the RefSeq Mash sketch in neissflow
   - Option 1: pass the path to RefSeqSketchesDefaults.msh to the pipeline as a parameter each run with the `--mash_db` argument
   - Option 2: change the default path for the `mash_db` parameter in [nextflow.config](../nextflow.config) to the path to RefSeqSketchesDefaults.msh
4. If you wish to test the pipeline with the test profile, you will need to change the paths of the test samples in [assets/samplesheet.csv](../assets/samplesheet.csv) to include the path to the repository on your system (ex: /repo path/assets/test_samples/sample_R1_001.fastq.gz)  
   Some sample output generated with these samples can also be found in `assets/sample_final_report.tsv` and `assets/sample_phylogeny_qc_report.tsv` for validating your test
5. Set the TMPDIR and TMP environment variables  
   On HPC systems the tmp directories on nodes can easily run out of space so it is best practice to set your temporary files to go to scratch. Neissflow contains modules that are configured to use these variables, so they will need to be set regardless of the system you are running on. Set these in a local or institutional profile you will be using to run neissflow with like the following example:

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

## Updating the mlst database

The mlst database should be updated regularly as we do not regularly update the database found in the repository. We recommend keeping a local copy of the database and updating it every 3 months. The neissflow copy of this database can be found [here](../assets/alleledb/mlst/).  

Use [BIGSdb_downloader](https://github.com/kjolley/BIGSdb_downloader) and [make_databases.sh](../assets/make_databases.sh) to download MLST alleles from PubMLST and make or update the neisseria mlst database.
   1. Create or access your [PubMLST](https://pubmlst.org/bigsdb) account
   2. Register your account for access to the Neisseria typing (pubmlst_neisseria_seqdef) database through My Account -> Database registrations and register under Auto-registrations.
      - Create an API Key through My Account -> API Keys
   3. Clone the [BIGSdb_downloader](https://github.com/kjolley/BIGSdb_downloader) repository
   ```
   git clone https://github.com/kjolley/BIGSdb_downloader.git
   ```
   4. Ensure you have [Python](https://www.python.org/) installed
   5. Install [rauth](https://rauth.readthedocs.io/en/latest/)
   ```
   pip install rauth
   ```
   6. Set up connection to BIGSdb (this is only active for an hour and this step will need to be repeated for any downloads to occur beyond 1 hour)
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
   7. Ensure you have [BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi) installed
   8. Run [make_databases.sh](../assets/make_databases.sh) (this script requires Python and rauth to run BIGSdb_downloader.py and BLAST+ to make the BLAST database)
   ```
   neissflow/assets/make_databases.sh -d "mlst" -k "<API KEY NAME>" -r /repo_path/BIGSdb_downloader -p mlst/pubmlst/ -b mlst/blastdb/ -t <TOKEN DIR FROM SETUP>
   ```
   9. Check that data has populated those directories & has read permissions
   10. Using this database in neissflow (if you have moved the database to a local directory):
     - Option 1: pass these paths to the pipeline as parameters each run with the arguments `--pubmlst` and `--blastdb`
     ```
     nextflow run CDCgov/neissflow -profile singularity --input samplesheet.csv --outdir out/ --pubmlst mlst/pubmlst/ --blastdb mlst/blastdb/ --only_fastq
     ```  
     These can also be added to a params.yml file, and included using the `-params-file` parameter
     - Option 2: change the default paths for `pubmlst` and `blastdb` variables in [nextflow.config](../nextflow.config)
   11. Test neissflow with the updated databases and check sample STs for expected results. If unexpected results are found (ST types are not being called, pipeline is failing) the database can be restored by removing any newly created files and renaming the old database files, removing the `.old` extension.

## Updating the NGMASTER database

It is recommended that you update the NGMASTER database at a regular frequency as new alleles and STs are always being added to PubMLST for NG-MAST and NG-STAR, and we do not regularly update the database in the repository. We recommend keeping a local copy of the database and updating it every 3 months. The neissflow copy of this database can be found [here](../assets/alleledb/ngmaster/).
  
Steps 1-7 from "Updating the mlst database" also apply for updating the NGMASTER database.

8. Run [make_databases.sh](../assets/make_databases.sh) (this script requires Python and rauth to run BIGSdb_downloader.py and BLAST+ to make the BLAST database)
   ```
   neissflow/assets/make_databases.sh -d "ngmaster" -k "<API KEY NAME>" -r /repo_path/BIGSdb_downloader -p ngmaster/pubmlst/ -b ngmaster/blastdb/ -t <TOKEN DIR FROM SETUP>
   ```
9. Check that data has populated those directories & has read permissions
10. Using this database in neissflow (if you have moved the database to a local directory):
   - Option 1: pass these paths to the pipeline as parameters each run with the arguments `--ngmasterdb`, `--ngstar`, and `--ngmast`
   ```
   nextflow run CDCgov/neissflow -profile singularity --input samplesheet.csv --outdir out/ --ngmasterdb ngmaster/ --ngstar ngmaster/pubmlst/ngstar/ngstar.txt --ngmast ngmaster/pubmlst/ngmast/ngmast.txt --only_fastq
   ```  
   These can also be added to a params.yml file, and included using the `-params-file` parameter
   - Option 2: change the default paths for `ngmasterdb`, `ngstar`, and `ngmast` variables in [nextflow.config](../nextflow.config)
11. Test neissflow with the updated databases and check sample NG-STAR & NG-MAST types for expected results. If unexpected results are found (types are not being called, pipeline is failing) the database can be restored by removing any newly created files and renaming the old database files, removing the `.old` extension.

## Updating the penA and porB BLAST databases

It is recommended that you update the penA and porB allele databases, as new alleles are added regularly and we do not consistently update the allele databases in this repository. We recommend keeping a local copy of the databases and updating it every 3 months. The neissflow copy of this database can be found [here](../assets/blastdb/).

Steps 1-7 from "Updating the mlst database" also apply for updating the NGMASTER database.

8. Run [make_databases.sh](../assets/make_databases.sh) (this script requires Python and rauth to run BIGSdb_downloader.py and BLAST+ to make the BLAST database)
   ```
   neissflow/assets/make_databases.sh -d "penAporB" -k "<API KEY NAME>" -r /repo_path/BIGSdb_downloader -p blastdb/ -b blastdb/ -t <TOKEN DIR FROM SETUP>
   ```
9. Check that data has populated those directories & has read permissions
10. Using this database in neissflow (if you have moved the database to a local directory):
   - Option 1: pass the database path to the pipeline each run with the argument `--a_blastdb`
   ```
   nextflow run CDCgov/neissflow -profile singularity --input samplesheet.csv --outdir out/ --a_blastdb allele_blastdb/ --only_fastq
   ```  
   This can also be added to a params.yml file, and included using the `-params-file` parameter
   - Option 2: change the default path for the `a_blastdb` variable in [nextflow.config](../nextflow.config)
11. Test neissflow with the updated databases and check sample penA & porB allele calls for expected results. If unexpected results are found (types are not being called, pipeline is failing) the database can be restored by removing any newly created files and renaming the old database files, removing the `.old` extension.

## Sample params.yml

If you choose to keep and update all of the databases locally, the easiest way to pass them to the pipeline is with the `-params-file` flag.  
  
```yaml title="params.yaml"
mash_db: RefSeqSketchesDefaults.msh
pubmlst: mlst/pubmlst/ 
blastdb: mlst/blastdb/
a_blastdb: allele_blastdb/ 
ngmasterdb: ngmaster/
ngstar: ngmaster/pubmlst/ngstar/ngstar.txt 
ngmast: ngmaster/pubmlst/ngmast/ngmast.txt
```
