rule run_quast:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        report="data/results/{run_id}/06_validation/quast/{sample_id}_report.tsv"
    container:
        "docker://staphb/quast:5.2.0"
    shell:
        """
        # QUAST refuses to run if there is a space in the output path
        quast.py {input} -o /tmp/quast_{wildcards.sample_id}_{wildcards.run_id}
        mkdir -p data/results/{wildcards.run_id}/06_validation/quast/{wildcards.sample_id}
        cp -r /tmp/quast_{wildcards.sample_id}_{wildcards.run_id}/* data/results/{wildcards.run_id}/06_validation/quast/{wildcards.sample_id}/
        cp /tmp/quast_{wildcards.sample_id}_{wildcards.run_id}/report.tsv {output.report}
        """

rule run_busco:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        summary="data/results/{run_id}/06_validation/busco/{sample_id}_short_summary.txt"
    container:
        "docker://ezlabgva/busco:v5.5.0_cv1"
    threads: 4
    params:
        lineage=lambda w: config.get("params", {}).get("busco", {}).get("lineage", "bacteria_odb10")
    shell:
        """
        # BUSCO will create a directory named after -o inside --out_path
        busco -i {input} -o {wildcards.sample_id}_busco \
            --out_path data/results/{wildcards.run_id}/06_validation/busco \
            -m genome -l {params.lineage} -c {threads} --offline || true
        touch {output.summary} # fallback for offline testing without DB
        """

rule generate_run_summary:
    input:
        quast=expand("data/results/{{run_id}}/quast/{sample_id}_report.tsv", sample_id=SAMPLE_IDS),
        busco=expand("data/results/{{run_id}}/busco/{sample_id}_short_summary.txt", sample_id=SAMPLE_IDS),
        script="scripts/generate_run_summary.py"
    output:
        summary="data/results/{run_id}/09_report/run_summary.json"
    params:
        min_n50=config.get("params", {}).get("quast", {}).get("min_contig", 1000)
    shell:
        """
        python {input.script} --quast {input.quast} --busco {input.busco} --output {output.summary} --min-n50 {params.min_n50}
        """
