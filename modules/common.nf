/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PROCESSES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
process IndexReference {
    container params.containers.samtools
    cpus 1
    memory 100.MB
    
    input:
        path(reference)
    
    output:
        tuple path(reference), path("${reference}.fai")

    script:
        """
        samtools faidx $reference
        """
}

process NameSortAlignments {
    publishDir { "${params.output_dir}/${sample_id}/concatemer_alignments" }, mode: 'copy'
    container params.containers.samtools
    cpus 1
    memory 1.GB

    input:
        tuple val(sample_id), val(file_id), path(sam)

    output:
        tuple val(sample_id), val(file_id), path("${file_id}.bam")

    script:
        """
        samtools sort -n -o ${file_id}.bam $sam
        """
}