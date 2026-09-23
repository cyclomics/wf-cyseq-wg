<p>
  <img src="assets/header.png" alt="header"/>
</p>

# CySeq Whole Genome

This workflow uses concatemeric CySeq reads as input to generate consensus reads in real time, using a whole reference genome as reference.

> <b>Expected use case:</b> <br>
> This workflow is designed specifically for ONT long-read sequencing reads generated using a CySeq Short Fragment sequencing kit. This is particularly useful for whole-genome cfDNA or sheared gDNA analyses. The workflow will generate consensus reads using the provided genome as reference, and provide metrics on the resolved DNA inserts.

<details>
  <summary><b>Table of contents</b></summary>

  - [Input requirements](#input-requirements)
  - [System requirements](#system-requirements)
  - [Software requirements](#software-requirements)
  - [General usage](#general-usage)
  - [Troubleshooting](#troubleshooting)

</details>

## Input requirements

The following are the most important inputs:

| Input | Format | Required | Description |
| ----- | ------ | -------- | ----------- |
| Sample name | Text | NO in CLI, YES in EPI2ME | Required for EPI2ME runs only. A descriptive name for your analysis run, relating to the sample being analysed. |
| Input data folder | Directory | YES | A MinKNOW sequencing output folder. Subdirectories of this folder are also allowed, **as long as they are above** the `fastq_pass` subdirectory. Within the directory or its subdirectories, MinKNOW will write the fastq_pass subfolder, which may optionally contain barcode subfolders, and the sequencing summary file, which is necessary to flag the end of the real time file ingestion. <br><br> The workflow monitors this folder continuously and automatically detects newly generated FASTQ files during sequencing. Analysis finishes automatically when the sequencing summary file indicates that sequencing has completed. **Thus, if the user selects any folder below the folder containing** `fastq_pass`**, or** `fastq_pass` **itself, the workflow will not be able to stop searching for new input FASTQ files.** <br><br> For example, such a folder may be any of the directories in the path: `EXPERIMENT_ID/SAMPLE_ID/SEQUENCING_RUN_OUTPUT/`, where `SEQUENCING_RUN_OUTPUT/` will contain `fastq_pass/`. <br><br> A `SEQUENCING_RUN_OUTPUT/` folder typically contains the date and flow cell ID and looks something like: `20260908_1627_P2S-02085-B_PBK94934_bee27c37.` <br><br> If barcoding was enabled during basecalling, barcode subdirectories are detected automatically and analysed separately. |
| Reference genome | FASTA | YES | Any reference genome in FASTA format. |
| Barcodes | Text | NO | Comma-delimited list of barcodes to be analysed. In the case of a barcoded run, a list of relevant barcodes may be provided (e.g. `barcode01,barcode02,barcode03`). If no list is provided, all detected barcodes will be analysed. If the run is not barcoded, this argument should not be provided. |
| Output folder | Directory | NO | The desired output folder name. If the folder does not yet exist, it will be created. Default: `output`. |

## Software requirements

This workflow makes use of Nextflow and Docker to execute and manage all other dependencies.

If you are executing this workflow through [EPI2ME](https://epi2me.nanoporetech.com/), then both these dependencies should be part of [its installation instructions](https://epi2me.nanoporetech.com/epi2me-docs/installation/). If you need to install them manually, please follow their official documentation:

- [Nextflow](https://docs.seqera.io/nextflow/install) (v23.04 or higher)
- [Docker](https://docs.docker.com/get-started/get-docker/)

## System requirements

The workflow expects at least 16 CPUs to be available and 32 GB of RAM. Please ensure you have at least 50 GB of disk space available.

We recommend at least 64 CPUs and 160 GB of RAM to decrease the runtime significantly. Primarily increasing the RAM allocation will allow the workflow to run more demanding processes in parallel, decreasing runtime. To further decrease runtime, allow 20 GB extra RAM for every 8 additional CPUs.

## General usage

<details>
  <summary><b><font size="+1">Through EPI2ME</font></b></summary>

  This pipeline is compatible with the EPI2ME platform by ONT. Please see [ONT's installation guide](https://epi2me.nanoporetech.com/epi2me-docs/quickstart/).

  **Installation on EPI2ME:**
  1. Open EPI2ME. Either login or click on the ellipsis ('...') and continue as guest.
  2. Navigate to 'Launch'.
  3. Click 'Import workflow'.
  4. Click 'Import from GitHub'
  3. Paste `https://github.com/cyclomics/wf-cyseq-wg` into the text bar and click 'Import workflow'.

  **Updating workflow on EPI2ME:**
  1. Open EPI2ME. Either login or click on the ellipsis ('...') and continue as guest.
  2. Navigate to ‘Launch’.
  3. Select ‘CySeq Whole Genome’.
  4. Click ‘Options’.
  5. Select ‘Check for updates’
  6. EPI2ME will download the latest available workflow release.

</details>

<details>
  <summary><b><font size="+1">Through command line</font></b></summary>

  In this section we assume that you have docker and nextflow installed on your system, if so running the pipeline is straightforward. You can run the pipeline directly from the repo:

  ```bash
  nextflow run cyclomics/wf-cyseq-wg \
    --input_dir /path/to/run_directory \
    --reference /path/to/reference.fasta \
    --output_dir /path/to/results
  ```

  If you would like to run first try running this with demo data:
  ```bash
  nextflow run cyclomics/wf-cyseq-wg \
    -profile demo,standard \
    --output_dir /path/to/results
  ```
</details>

## Troubleshooting

If you encounter any issues with the workflow where there is unexpected behaviour, then we kindly request that you [submit an issue on the GitHub repository](https://github.com/cyclomics/wf-cyseq-wg/issues). This helps the development team address your issues quickly.

Alternatively, you can e-mail Cyclomics directly at cyseq@cyclomics.com.
