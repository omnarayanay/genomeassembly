rule kraken2_screen:
    input:
        "data/work/{run_id}/02_trim_final/{sample_id}_trimmed.fastq.gz"
    output:
        report="data/results/{run_id}/03_screen/kraken/{sample_id}_kraken_report.txt",
        output="data/results/{run_id}/03_screen/kraken/{sample_id}_kraken_output.txt"
    container:
        "docker://staphb/kraken2:2.1.3"
    threads: 4
    resources:
        mem_mb=8192
    shell:
        """
        echo "Kraken2 mock run" > {output.report}
        echo "Kraken2 mock output" > {output.output}
        """

rule fastq_screen:
    input:
        "data/work/{run_id}/02_trim_final/{sample_id}_trimmed.fastq.gz"
    output:
        "data/results/{run_id}/03_screen/fastq_screen/{sample_id}_trimmed_screen.txt"
    # container:
    #     "docker://staphb/fastq_screen:0.15.3"
    shell:
        """
        echo "FastQ Screen mock run" > {output}
        """
