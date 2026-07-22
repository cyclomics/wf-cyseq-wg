/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
workflow merge_consensus {
    take:
        sam_files

    main:
        ConcatSamFiles(sam_files)
        merged_bam = ConcatSamFiles.out
        PosSortIndexAlignments(merged_bam)
        sorted_bam = PosSortIndexAlignments.out
        DeduplicateByPosition(merged_bam.combine(sorted_bam, by: [0, 1]))

    emit:
        merged_bam
        sorted_bam
        dedup_bam = DeduplicateByPosition.out.map { it -> tuple(it[0], it[1], it[2]) }
        dedup_metrics = DeduplicateByPosition.out.map { it -> tuple(it[0], it[3]) }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PROCESSES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process Minimap2Align {
    container params.containers.minimap2
    cpus 4
    memory 15.GB

    input:
        tuple val(sample_id), val(file_id), path(fq)
        tuple path(reference), val(reference_idx)
        val(mode)
    
    output:
        tuple val(sample_id), val(file_id), path("${file_id}.sam") 

    script:
        """
        minimap2 -ax ${mode} \\
            -t ${task.cpus} \\
            -k15 -w5 -m20 -n3 \\
            $reference \\
            $fq > ${file_id}.sam
        """
}

process ConcatSamFiles {
    publishDir { "${params.output_dir}/${sample_id}/consensus_alignments" }, mode: 'copy'
    container params.containers.samtools
    cpus 1
    memory 2.GB

    input:
        tuple val(sample_id), val(file_ids), path(sams_in)

    output:
        tuple val(sample_id), val(sample_id), path("${sample_id}.merged.bam")

    script:
        def samFiles = sams_in.collect { file -> file.getName() }.join(' ')
        """
        for sam in ${samFiles}; do
            samtools view -b "\$sam" > "\${sam%.sam}.bam"
        done

        samtools cat -o ${sample_id}.merged.bam *.bam
        """
}

process PosSortIndexAlignments {
    publishDir { "${params.output_dir}/${sample_id}/consensus_alignments" }, mode: 'copy'
    container params.containers.samtools
    cpus 1
    memory 100.MB

    input:
        tuple val(sample_id), val(file_id), path(bam)

    output:
        tuple val(sample_id), val(file_id), path("${file_id}.bam"), path("${file_id}.bam.bai") 

    script:
        """
        samtools sort -o ${file_id}.bam $bam
        samtools index ${file_id}.bam
        """
}

process DeduplicateByPosition {
    publishDir { "${params.output_dir}/${sample_id}/deduplicate" }, mode: 'copy', pattern: "*.bam"
    publishDir { "${params.output_dir}/${sample_id}/report" }, mode: 'copy', pattern: "*.read_metrics"
    container params.containers.cyseqtools
    cpus 1
    memory 20.GB
    
    input:
        tuple val(sample_id), val(file_id), path(unsorted_bam), path(sorted_bam), path(sorted_bai)

    output:
        tuple val(sample_id), val(file_id), path("${file_id}.dedup.bam"), path(".read_metrics")
    
    script:
        """
        cyseqtools deduplicate mapping \
            -i ${unsorted_bam} \
            -s ${sorted_bam} \
            -o ${file_id}.dedup.bam \
            --metrics-path .read_metrics
        """
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/