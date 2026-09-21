rule run_multiqc:
    input:
        qc=get_all_qc_outputs,
        quast=expand("data/results/{{run_id}}/quast/{sample_id}_report.tsv", sample_id=SAMPLE_IDS),
        busco=expand("data/results/{{run_id}}/busco/{sample_id}_short_summary.txt", sample_id=SAMPLE_IDS)
    output:
        html="data/results/{run_id}/09_report/multiqc_report.html"
    container:
        "docker://staphb/multiqc:1.35"
    shell:
        """
        multiqc data/results/{wildcards.run_id} -o data/results/{wildcards.run_id}/09_report
        """
