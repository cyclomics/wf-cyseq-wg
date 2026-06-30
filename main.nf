#!/usr/bin/env nextflow
/*
========================================================================================
    Workflow name
========================================================================================
    Github: https://github.com/cyclomics/wf-cyseq-wg
    Website: https://www.cyclomics.com/
----------------------------------------------------------------------------------------
*/

nextflow.preview.recursion = true

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / PROCESSES / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { ingress } from './modules/ingress'
include {
    IndexReference;
    } from './modules/common'
include { make_consensus } from './modules/consensus'
include {
    align_consensus;
    merge_consensus;
    } from './modules/alignment'
include {
    report_live;
    FinalizeReport
    } from './modules/report'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
workflow {
    assert params.input_dir : "--input_dir cannot be empty. Please provide a folder containing input FASTQ files or containing a subfolder with input FASTQ files."
    assert params.reference : "--reference cannot be empty. Please provide a reference genome in FASTA format. Variant annotation is only compatible with GRCh38."

    def allowed_modes = ["map-ont", "sr"]
    assert params.minimap2?.mode in allowed_modes :
        "--minimap2.mode must be one of: ${allowed_modes.join(', ')}"

    def read_pattern = params.input_dir.endsWith("/")
            ? "${params.input_dir}${params.read_pattern}"
            : "${params.input_dir}/${params.read_pattern}"
        
    def stop_pattern = params.input_dir.endsWith("/")
        ? "${params.input_dir}${params.stop_pattern}"
        : "${params.input_dir}/${params.stop_pattern}"

    def ch_reference = IndexReference(channel.fromPath(params.reference)).collect()
    def minimap2_mode = params.minimap2.mode

    // Start ingress workflow
    ingress(read_pattern, stop_pattern)
    raw_fastq = ingress.out.ingested_fastq

    // Consensus
    make_consensus(raw_fastq, ch_reference)
    consensus_bam = make_consensus.out.consensus_bam
    consensus_folder = make_consensus.out.consensus_folder

    // Live report
    report_live(
        consensus_folder,
    )

    // Merge all alignments
    grouped_consensus_bam = consensus_bam
            .groupTuple(by: 0)

    merge_consensus(grouped_consensus_bam)
    dedup_metrics = merge_consensus.out.dedup_metrics

    // Final report
    FinalizeReport(
        report_live.out.live_report
            .groupTuple(by: 0)
            .map { sample_id, htmls, jsons -> tuple(sample_id, htmls[-1], jsons[-1]) }
            .combine(dedup_metrics, by: 0)
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
