include { PosSortIndexAlignments } from './common'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
workflow align_consensus {
    take:
        consensus_reads
        reference
        regions
        mode

    main:
        Minimap2Align(consensus_reads, reference, mode)
        PosSortIndexAlignments(Minimap2Align.out)
        aligned_consensus_bam = PosSortIndexAlignments.out


    emit:
        aligned_consensus_bam
}


workflow merge_consensus {
    take:
        annotated_bam_files

    main:
        MergeBamFiles(annotated_bam_files)
        merged_bam = MergeBamFiles.out

    emit:
        merged_bam
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PROCESSES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process Minimap2Align {
    container params.containers.minimap2
    cpus 8
    memory 20.GB

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
            $reference \\
            $fq > ${file_id}.sam
        """
}

process MergeBamFiles {
    publishDir { "${params.output_dir}/${sample_id}/consensus_alignments" }, mode: 'copy'
    container params.containers.samtools

    input:
        tuple val(sample_id), val(file_ids), path(bams_in)

    output:
        tuple val(sample_id), val(sample_id), path("${sample_id}.merged.bam"), path("${sample_id}.merged.bam.bai")
    
    script:
        """
        samtools merge -p -c -O bam ${sample_id}.merged.bam \$(find . -name '*.bam')
        samtools index ${sample_id}.merged.bam
        """
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/