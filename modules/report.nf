/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow report_live {
    take:
        consensus_folder // [sample_id, file_id, read_metrics_folder]

    main:
        // Accumulate read metrics
        live_read_metrics = consensus_folder
            .map { sample_id, file_id, read_metrics_folder ->
                tuple(sample_id, file_id, read_metrics_folder, consensusMetricsFolder(sample_id))
            }
            | StreamReadMetrics
            | map { sample_id, file_id, _dir, cards, plots ->
                tuple(sample_id, file_id, cards, plots)
            }


        ReportStreamData(live_read_metrics)
        live_report = ReportStreamData.out.report

    emit:
        live_report
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PROCESSES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process StreamReadMetrics {
    container params.containers.cyseqtools
    maxForks 1
    publishDir { "${params.output_dir}/${sample_id}/report" }, mode: 'copy', overwrite: true

    input:
        tuple val(sample_id), val(file_id), path(metrics_folder), path(published_folder)

    output:
        tuple val(sample_id), val(file_id), path(".read_metrics"), path("cards/cards.yaml"), path("plots/*.yaml")

    script:
        """
        mv $published_folder .prev_read_metrics
        sum_read_metrics.py \
            --metrics_folder $metrics_folder \
            --published_folder $published_folder
        """
}

process ReportStreamData {
    container params.containers.alnutils
    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), val(file_id),
              path(consensus_cards_yml), path(consensus_yml)

    output:
        tuple val(sample_id), path("report_${sample_id}.html"), path("report_${sample_id}.json"), emit: report

    script:
        """
        report_live.py \
            --template ${params.report_template} \
            --output_html report_${sample_id}.html \
            --output_json report_${sample_id}.json
        """
}

process FinalizeReport {
    container params.containers.alnutils
    publishDir "${params.output_dir}", mode: 'copy'

    input:
        tuple val(sample_id), path(report_html), path(report_json)

    output:
        path("report_${sample_id}.html")

    script:
        """
        finalize_report.py \
            --html ${report_html} \
            --json ${report_json} \
            --output report_${sample_id}.html
        """
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def reportsDir(sample_id) {
    "${params.output_dir}/${sample_id}/report"
}

def consensusMetricsFolder(sample_id) {
    files("${reportsDir(sample_id)}/.read_metrics")
}