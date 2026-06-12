/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

process SplitReadFilesOnNumberOfReads {
    container params.containers.seqkit
    cpus 4

    input:
        tuple val(sample_id), val(file_id), path(fq)

    output:
        tuple val(sample_id), val(file_id), path("split/${file_id}_*.fastq")

    script:
        """
        seqkit split -j ${task.cpus} -e .gz -s $params.max_fastq_size --by-size-prefix ${file_id}_ -O split $fq
        gunzip split/*.gz
        """
}

process IndexReference {
    container params.containers.samtools
    
    input:
        path(reference)
    
    output:
        tuple path(reference), path("${reference}.fai")

    script:
        """
        samtools faidx $reference
        """
}

process PosSortIndexAlignments {
    container params.containers.samtools

    input:
        tuple val(sample_id), val(file_id), path(sam)

    output:
        tuple val(sample_id), val(file_id), path("${file_id}.bam"), path("${file_id}.bam.bai") 

    script:
        """
        samtools sort -o ${file_id}.bam $sam
        samtools index ${file_id}.bam
        """
}

process NameSortAlignments {
    publishDir { "${params.output_dir}/${sample_id}/concatemer_alignments" }, mode: 'copy'
    container params.containers.samtools

    input:
        tuple val(sample_id), val(file_id), path(sam)

    output:
        tuple val(sample_id), val(file_id), path("${file_id}.bam")

    script:
        """
        samtools sort -n -o ${file_id}.bam $sam
        """
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PROCESSES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
process testProcess {
    label 'standard'
    
    input:
        path reference_genome

    output:
        path reference_genome

    script:
        """
        echo $reference_genome
        """

    stub:
        """
        echo $reference_genome
        """
}

process getFirstRead {
    cpus 4
    memory '6 GB'

    input:
        path read_fastq

    output:
        path read_fastq

    script:
        """
        head -n 4 $read_fastq > first_read.fastq
        """

    stub:
        """
        head -n 4 $read_fastq > first_read.fastq
        """
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/