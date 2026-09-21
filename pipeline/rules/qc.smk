rule fastqc_R1:
    input:
        get_read1
    output:
        html="data/results/{run_id}/01_qc/{sample_id}_R1_fastqc.html",
        zip="data/results/{run_id}/01_qc/{sample_id}_R1_fastqc.zip"
    container:
        "docker://staphb/fastqc:0.12.1"
    shell:
        """
        fastqc {input} --outdir data/results/{wildcards.run_id}/01_qc/
        mv data/results/{wildcards.run_id}/01_qc/$(basename {input} .fastq.gz)_fastqc.html {output.html}
        mv data/results/{wildcards.run_id}/01_qc/$(basename {input} .fastq.gz)_fastqc.zip {output.zip}
        """

rule fastqc_R2:
    input:
        get_read2
    output:
        html="data/results/{run_id}/01_qc/{sample_id}_R2_fastqc.html",
        zip="data/results/{run_id}/01_qc/{sample_id}_R2_fastqc.zip"
    container:
        "docker://staphb/fastqc:0.12.1"
    shell:
        """
        fastqc {input} --outdir data/results/{wildcards.run_id}/01_qc/
        mv data/results/{wildcards.run_id}/01_qc/$(basename {input} .fastq.gz)_fastqc.html {output.html}
        mv data/results/{wildcards.run_id}/01_qc/$(basename {input} .fastq.gz)_fastqc.zip {output.zip}
        """

rule nanoplot_raw:
    input:
        get_long_reads
    output:
        report="data/results/{run_id}/01_qc/{sample_id}_nanoplot/NanoPlot-report.html"
    container:
        "docker://staphb/nanoplot:1.41.0"
    shell:
        """
        NanoPlot --fastq {input} -o data/results/{wildcards.run_id}/01_qc/{wildcards.sample_id}_nanoplot
        """
