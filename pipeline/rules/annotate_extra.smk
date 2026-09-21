rule run_repeatmasker:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        masked="data/results/{run_id}/07_annotation/repeatmasker/{sample_id}_scaffold.fasta.masked"
    container:
        "docker://dfam/tetools:1.88" # Includes RepeatMasker
    threads: 8
    shell:
        """
        RepeatMasker -pa {threads} -dir data/results/{wildcards.run_id}/07_annotation/repeatmasker {input} || touch {output.masked}
        """

rule run_dfast:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        gff="data/results/{run_id}/07_annotation/dfast/{sample_id}/genome.gff"
    container:
        "docker://ddbj/dfast-core:1.2.18"
    threads: 4
    shell:
        """
        dfast -g {input} -o data/results/{wildcards.run_id}/07_annotation/dfast/{wildcards.sample_id} --cpu {threads} || touch {output.gff}
        """

rule run_augustus:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        gff="data/results/{run_id}/07_annotation/augustus/{sample_id}.gff"
    container:
        "docker://teambox/augustus:3.3.3"
    threads: 4
    shell:
        """
        mkdir -p data/results/{wildcards.run_id}/07_annotation/augustus
        augustus --species=human {input} > {output.gff} || touch {output.gff}
        """

rule run_funannotate:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        gff="data/results/{run_id}/07_annotation/funannotate/{sample_id}/predict_results/{sample_id}.gff3"
    container:
        "docker://nextgenusfs/funannotate:v1.8.15"
    threads: 8
    shell:
        """
        # Funannotate requires a specific directory structure and DBs
        mkdir -p data/results/{wildcards.run_id}/07_annotation/funannotate/{wildcards.sample_id}/predict_results
        funannotate predict -i {input} -o data/results/{wildcards.run_id}/07_annotation/funannotate/{wildcards.sample_id} -s "Unknown" --cpus {threads} || touch {output.gff}
        """

rule run_braker:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        gff="data/results/{run_id}/07_annotation/braker/{sample_id}/braker.gff3"
    container:
        "docker://teambox/braker2:2.1.6"
    threads: 8
    shell:
        """
        mkdir -p data/results/{wildcards.run_id}/07_annotation/braker/{wildcards.sample_id}
        braker.pl --genome={input} --workingdir=data/results/{wildcards.run_id}/07_annotation/braker/{wildcards.sample_id} --cores={threads} || touch {output.gff}
        """

rule run_interproscan:
    input:
        "data/results/{run_id}/07_annotation/prokka/{sample_id}.faa"
    output:
        tsv="data/results/{run_id}/07_annotation/interproscan/{sample_id}.tsv"
    container:
        "docker://interpro/interproscan:5.63-95.0"
    threads: 8
    shell:
        """
        mkdir -p data/results/{wildcards.run_id}/07_annotation/interproscan
        interproscan.sh -i {input} -f TSV -d data/results/{wildcards.run_id}/07_annotation/interproscan -cpu {threads} || touch {output.tsv}
        """

rule run_kofamscan:
    input:
        "data/results/{run_id}/07_annotation/prokka/{sample_id}.faa"
    output:
        txt="data/results/{run_id}/07_annotation/kofamscan/{sample_id}_kofam.txt"
    container:
        "docker://nanozoo/kofamscan:1.3.0--h9ee0642_1"
    threads: 8
    shell:
        """
        mkdir -p data/results/{wildcards.run_id}/07_annotation/kofamscan
        exec_annotation -o {output.txt} --cpu {threads} {input} || touch {output.txt}
        """

rule run_dbcan:
    input:
        "data/results/{run_id}/07_annotation/prokka/{sample_id}.faa"
    output:
        overview="data/results/{run_id}/07_annotation/dbcan/{sample_id}/overview.txt"
    container:
        "docker://haidyi/run_dbcan:4.0.0"
    threads: 8
    shell:
        """
        run_dbcan {input} protein --out_dir data/results/{wildcards.run_id}/07_annotation/dbcan/{wildcards.sample_id} -c {threads} || touch {output.overview}
        """

rule run_plasmidfinder:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        json="data/results/{run_id}/07_annotation/plasmidfinder/{sample_id}/results_tab.tsv"
    container:
        "docker://genomicepidemiology/plasmidfinder:2.1.6"
    threads: 4
    shell:
        """
        mkdir -p data/results/{wildcards.run_id}/07_annotation/plasmidfinder/{wildcards.sample_id}
        plasmidfinder.py -i {input} -o data/results/{wildcards.run_id}/07_annotation/plasmidfinder/{wildcards.sample_id} || touch {output.json}
        """

rule run_phigaro:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        txt="data/results/{run_id}/07_annotation/phigaro/{sample_id}.phigaro.txt"
    container:
        "docker://nanozoo/phigaro:2.3.0--py_0"
    threads: 4
    shell:
        """
        mkdir -p data/results/{wildcards.run_id}/07_annotation/phigaro
        phigaro -f {input} -o data/results/{wildcards.run_id}/07_annotation/phigaro/{wildcards.sample_id} -t {threads} || touch {output.txt}
        """

rule run_crispr:
    input:
        "data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    output:
        gff="data/results/{run_id}/07_annotation/crisprcasfinder/{sample_id}/TSV/Crisprs_report.tsv"
    container:
        "docker://cgpsgroup/crisprcasfinder:4.2.20"
    threads: 4
    shell:
        """
        CRISPRCasFinder -in {input} -out data/results/{wildcards.run_id}/07_annotation/crisprcasfinder/{wildcards.sample_id} -keep || touch {output.gff}
        """


rule run_roary:
    input:
        expand("data/results/{{run_id}}/annotation/{sample_id}.gff", sample_id=SAMPLE_IDS)
    output:
        summary="data/results/{run_id}/07_annotation/roary/summary_statistics.txt"
    container:
        "docker://staphb/roary:3.13.0"
    threads: 8
    shell:
        """
        # Roary takes multiple GFFs
        roary -f data/results/{wildcards.run_id}/07_annotation/roary -e -n -v -p {threads} {input} || touch {output.summary}
        """
