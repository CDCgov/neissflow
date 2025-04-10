# neissflow: Usage

## Introduction

neissflow can be ran from the command line or Nextflow Tower.

## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyze before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 2-4 columns, and a header row.

```bash
--input '[path to samplesheet file]'
```

### Full samplesheet

To generate a samplesheet of paired-end FASTQ files use the script found at `/<path to neissflow>/bin/fastq_dir_to_samplesheet.py`. The directory used to generate the samplesheet should ONLY contain samples to be analyzed as part of the run.

Ensure you have Python3 installed to run the script.

**Example run:**  
```
$ python3 /<path to neissflow>/bin/fastq_dir_to_samplesheet.py <FASTQ DIR> <SAMPLESHEET_FILE>
```
Here are all of the usage instructions for running the samplesheet generation script, in case you would like to manipulate the sample names at all.
```
usage: fastq_dir_to_samplesheet.py [-h] [-r1 READ1_EXTENSION] [-r2 READ2_EXTENSION] [-sn] [-sd SANITISE_NAME_DELIMITER] [-si SANITISE_NAME_INDEX] FASTQ_DIR SAMPLESHEET_FILE

Generate nf-core/neissflow samplesheet from a directory of FastQ files.

positional arguments:
  FASTQ_DIR             Folder containing raw FastQ files.
  SAMPLESHEET_FILE      Output samplesheet file.

optional arguments:
  -h, --help            show this help message and exit
  -r1 READ1_EXTENSION, --read1_extension READ1_EXTENSION
                        File extension for read 1.
  -r2 READ2_EXTENSION, --read2_extension READ2_EXTENSION
                        File extension for read 2.
  -sn, --sanitise_name  Whether to further sanitise FastQ file name to get sample id. Used in conjunction with --sanitise_name_delimiter and --sanitise_name_index.
  -sd SANITISE_NAME_DELIMITER, --sanitise_name_delimiter SANITISE_NAME_DELIMITER
                        Delimiter to use to sanitise sample name.
  -si SANITISE_NAME_INDEX, --sanitise_name_index SANITISE_NAME_INDEX
                        After splitting FastQ file name by --sanitise_name_delimiter all elements before this index (1-based) will be joined to create final sample name.

Example usage: python fastq_dir_to_samplesheet.py <FASTQ_DIR> <SAMPLESHEET_FILE>
```
The script will produce a samplesheet with the following format:
```
sample,fastq_1,fastq_2
AEG588A1,/path/AEG588A1_S1_L002_R1_001.fastq.gz,/path/AEG588A1_S1_L002_R2_001.fastq.gz
```
If you are including contigs for each of these samples, you will need to add the path to the FASTA files (manually or with your own script) so that the samplesheet has the following format:
```
sample,fastq_1,fastq_2,fasta
AEG588A1,/path/AEG588A1_S1_L002_R1_001.fastq.gz,/path/AEG588A1_S1_L002_R2_001.fastq.gz,/path/AEG588A1_contigs.fasta
```
If you are only running the pipeline on assemblies, you will have to generate a samplesheet (manually or with your own script) containing only the sample and fasta fields:
```
sample,fasta
AEG588A1,/path/AEG588A1_contigs.fasta
```

| Column    | Description                                                                                                                                                                            |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sample`  | Custom sample name. This entry will be identical for multiple sequencing libraries/runs from the same sample. Spaces in sample names are automatically converted to underscores (`_`). |
| `fastq_1` | Full path to FastQ file for Illumina short reads 1. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz".                                                             |
| `fastq_2` | Full path to FastQ file for Illumina short reads 2. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz". |
| `fasta`   | Full path to FASTA assembly file. File has to have extension ".fasta" or ".fa"                                                           |

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

## Running the pipeline

The typical command for running the pipeline is as follows (ensure to replace the "all" profile with whatever profile is fit for your environment):

```bash
nextflow run neissflow -profile singularity,all --input samplesheet.csv --outdir <OUTDIR> --name <RUN NAME> --only_fastq
```

This will launch the pipeline with the `singularity` and `all` configuration profiles. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

:::warning
Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/usage/configuration#tuning-workflow-resources), other infrastructural tweaks (such as output directories), or module arguments (args).
:::

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run neissflow -profile singularity,all,QC -params-file params.yaml
```

with `params.yaml` containing:

```yaml
input: './samplesheet.csv'
outdir: './results/'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Reproducibility

It is a good idea to specify a pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [neissflow releases page](https://github.com/CDCgov/neissflow/-/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducbility, you can use share and re-use [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

:::tip
If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.
:::

## Core Nextflow arguments

:::note
These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).
:::

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

:::info
We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.
:::

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to see if your system is available in these configs please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile singularity,all,test` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer enviroment.

- `test`
  - A profile with a complete configuration for automated testing with FASTQ input
  - Includes links to test data so needs no other parameters
- `test_both`
  - A profile with a complete configuration for automated testing with FASTQ and FASTA input
  - Includes links to test data so needs no other parameters
- `test_fasta`
  - A profile with a complete configuration for automated testing with FASTA input
  - Includes links to test data so needs no other parameters
- `all`
  - A profile configured to run on an sge system's all.q queue
- `short`
  - A profile configured to run on an sge system's short.q queue
- `highmem`
  - A profile configured to run on an sge system's highmem.q queue
- `singularity`
  - A configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `QC` 
  - A profile with configuration for running control sample FASTQ files through the pipeline during your run
  - Will not run control samples if only FASTA files are included in the run samplesheet 

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).
