rule run_blastx:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        xml="data/results/{run_id}/08_identification/blastx/{sample_id}_blastx.xml"
    container:
        "docker://ncbi/blast:2.15.0"
    threads: 8
    params:
        # Default omicsbox blast config: outfmt 5 is XML
        taxid=lambda w: config.get("params", {}).get("blast", {}).get("taxid", "4910"),
        db="nr" # would ideally mount a local DB
    shell:
        """
        mkdir -p data/results/{wildcards.run_id}/08_identification/blastx
        # Real remote execution via NCBI API. 
        # Note: -remote does not support -num_threads.
        blastx -query {input} -db {params.db} -outfmt 5 -out {output.xml} -remote -taxids {params.taxid}
        """

rule run_blastn:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        xml="data/results/{run_id}/08_identification/blastn/{sample_id}_blastn.xml"
    container:
        "docker://ncbi/blast:2.15.0"
    threads: 1
    params:
        taxid=lambda w: config.get("params", {}).get("blast", {}).get("taxid", "4910"),
        db="nt"
    shell:
        """
        mkdir -p data/results/{wildcards.run_id}/08_identification/blastn
        # Real remote execution via NCBI API.
        blastn -query {input} -db {params.db} -outfmt 5 -out {output.xml} -remote -taxids {params.taxid}
        """

rule run_blastp:
    input:
        "data/results/{run_id}/07_annotation/prokka/{sample_id}.faa"
    output:
        xml="data/results/{run_id}/08_identification/blastp/{sample_id}_blastp.xml"
    container:
        "docker://ncbi/blast:2.15.0"
    threads: 1
    params:
        taxid=lambda w: config.get("params", {}).get("blast", {}).get("taxid", "4910"),
        db="nr"
    shell:
        """
        mkdir -p data/results/{wildcards.run_id}/08_identification/blastp
        # Real remote execution via NCBI API.
        blastp -query {input} -db {params.db} -outfmt 5 -out {output.xml} -remote -taxids {params.taxid}
        """
