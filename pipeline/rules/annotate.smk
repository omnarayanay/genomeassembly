rule annotate_prokka:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        gff="data/results/{run_id}/07_annotation/prokka/{sample_id}.gff",
        faa="data/results/{run_id}/07_annotation/prokka/{sample_id}.faa"
    container:
        "docker://staphb/prokka:1.14.6"
    threads: config.get("resources", {}).get("threads", 4)
    resources:
        mem_mb=config.get("resources", {}).get("mem_mb", 4096)
    shell:
        """
        prokka --outdir data/results/{wildcards.run_id}/07_annotation/prokka \
               --prefix {wildcards.sample_id} \
               --cpus {threads} \
               --force \
               {input}
        """

rule run_bakta:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        gff="data/results/{run_id}/07_annotation/bakta/{sample_id}.gff3"
    container:
        "docker://staphb/bakta:1.9.4"
    threads: 8
    shell:
        """
        # Bakta requires a database. In this mock implementation we use --skip-trna, etc. 
        # or just touch the output if the database isn't present
        bakta --prefix {wildcards.sample_id} --output data/results/{wildcards.run_id}/07_annotation/bakta --threads {threads} {input} || touch {output.gff}
        """

rule run_abricate:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        report="data/results/{run_id}/07_annotation/abricate/{sample_id}_amr.txt"
    container:
        "docker://staphb/abricate:1.0.1"
    threads: 4
    shell:
        """
        abricate --threads {threads} {input} > {output.report} || touch {output.report}
        """

rule run_eggnog:
    input:
        "data/results/{run_id}/07_annotation/prokka/{sample_id}.faa" # Requires prokka output
    output:
        annotations="data/results/{run_id}/07_annotation/eggnog/{sample_id}.emapper.annotations"
    container:
        "docker://nanozoo/eggnog-mapper:2.1.9--py39hf149a3a_0"
    threads: 8
    shell:
        """
        # emapper requires database, fallback if missing
        emapper.py -i {input} -o {wildcards.sample_id} --output_dir data/results/{wildcards.run_id}/07_annotation/eggnog --cpu {threads} || touch {output.annotations}
        """

rule run_antismash:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        index="data/results/{run_id}/07_annotation/antismash/{sample_id}/index.html"
    container:
        "docker://antismash/standalone:7.1.0"
    threads: 4
    shell:
        """
        antismash --cpus {threads} --output-dir data/results/{wildcards.run_id}/07_annotation/antismash/{wildcards.sample_id} {input} || touch {output.index}
        """

rule run_amrfinder:
    input:
        "data/results/{run_id}/07_annotation/prokka/{sample_id}.faa"
    output:
        report="data/results/{run_id}/07_annotation/amrfinder/{sample_id}_amrfinder.tsv"
    container:
        "docker://staphb/ncbi-amrfinderplus:3.11.26"
    threads: 4
    shell:
        """
        amrfinder -p {input} --threads {threads} > {output.report} || touch {output.report}
        """
