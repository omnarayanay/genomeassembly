rule assemble_short:
    input:
        short="data/work/{run_id}/02_trim/{sample_id}_fastp_trimmed.fastq.gz",
        kraken="data/results/{run_id}/03_screen/kraken/{sample_id}_kraken_report.txt",
        fqscreen="data/results/{run_id}/03_screen/fastq_screen/{sample_id}_trimmed_screen.txt"
    output:
        fasta="data/work/{run_id}/04_assembly/{sample_id}_short_assembly.fasta"
    container:
        "docker://staphb/spades:3.15.5"
    threads: config.get("resources", {}).get("threads", 4)
    shell:
        """
        spades.py -s {input.short} -o data/work/{wildcards.run_id}/04_assembly_out_short_{wildcards.sample_id} -t {threads}
        cp data/work/{wildcards.run_id}/04_assembly_out_short_{wildcards.sample_id}/scaffolds.fasta {output.fasta}
        """

rule assemble_long:
    input:
        long="data/work/{run_id}/02_trim/{sample_id}_chopper_trimmed.fastq.gz",
        kraken="data/results/{run_id}/03_screen/kraken/{sample_id}_kraken_report.txt",
        fqscreen="data/results/{run_id}/03_screen/fastq_screen/{sample_id}_trimmed_screen.txt"
    output:
        fasta="data/work/{run_id}/04_assembly/{sample_id}_long_assembly.fasta"
    container:
        "docker://staphb/flye:2.9.3"
    threads: config.get("resources", {}).get("threads", 4)
    shell:
        """
        flye --nano-raw {input.long} --out-dir data/work/{wildcards.run_id}/04_assembly_out_long_{wildcards.sample_id} --threads {threads}
        cp data/work/{wildcards.run_id}/04_assembly_out_long_{wildcards.sample_id}/assembly.fasta {output.fasta}
        """

rule assemble_hybrid:
    input:
        short="data/work/{run_id}/02_trim/{sample_id}_fastp_trimmed.fastq.gz",
        long="data/work/{run_id}/02_trim/{sample_id}_chopper_trimmed.fastq.gz",
        kraken="data/results/{run_id}/03_screen/kraken/{sample_id}_kraken_report.txt",
        fqscreen="data/results/{run_id}/03_screen/fastq_screen/{sample_id}_trimmed_screen.txt"
    output:
        fasta="data/work/{run_id}/04_assembly/{sample_id}_hybrid_assembly.fasta"
    container:
        "docker://staphb/spades:3.15.5"
    threads: config.get("resources", {}).get("threads", 4)
    shell:
        """
        spades.py -s {input.short} --nanopore {input.long} -o data/work/{wildcards.run_id}/04_assembly_out_hybrid_{wildcards.sample_id} -t {threads}
        cp data/work/{wildcards.run_id}/04_assembly_out_hybrid_{wildcards.sample_id}/scaffolds.fasta {output.fasta}
        """

rule assemble_unicycler:
    input:
        short="data/work/{run_id}/02_trim/{sample_id}_fastp_trimmed.fastq.gz",
        long="data/work/{run_id}/02_trim/{sample_id}_chopper_trimmed.fastq.gz",
        kraken="data/results/{run_id}/03_screen/kraken/{sample_id}_kraken_report.txt",
        fqscreen="data/results/{run_id}/03_screen/fastq_screen/{sample_id}_trimmed_screen.txt"
    output:
        fasta="data/work/{run_id}/04_assembly/{sample_id}_unicycler_assembly.fasta"
    container:
        "docker://staphb/unicycler:0.5.0"
    threads: config.get("resources", {}).get("threads", 4)
    shell:
        """
        unicycler -s {input.short} -l {input.long} -o data/work/{wildcards.run_id}/04_assembly_unicycler_{wildcards.sample_id} -t {threads}
        cp data/work/{wildcards.run_id}/04_assembly_unicycler_{wildcards.sample_id}/assembly.fasta {output.fasta}
        """

def get_final_assembly(wildcards):
    s = SAMPLE_DICT[wildcards.sample_id]
    rtype = s.get("read_type")
    tools = config.get("params", {}).get("selected_tools", [])
    
    if rtype == "long":
        if "raven" in tools:
            return f"data/work/{wildcards.run_id}/04_assembly/{wildcards.sample_id}_raven_assembly.fasta"
        elif "canu" in tools:
            return f"data/work/{wildcards.run_id}/04_assembly/{wildcards.sample_id}_canu_assembly.fasta"
        else:
            return f"data/work/{wildcards.run_id}/04_assembly/{wildcards.sample_id}_long_assembly.fasta" # flye default
    elif rtype == "hybrid":
        if "unicycler" in tools:
            return f"data/work/{wildcards.run_id}/04_assembly/{wildcards.sample_id}_unicycler_assembly.fasta"
        elif "masurca" in tools:
            return f"data/work/{wildcards.run_id}/04_assembly/{wildcards.sample_id}_masurca_assembly.fasta"
        else:
            return f"data/work/{wildcards.run_id}/04_assembly/{wildcards.sample_id}_hybrid_assembly.fasta" # spades default
    else:
        if "skesa" in tools:
            return f"data/work/{wildcards.run_id}/04_assembly/{wildcards.sample_id}_skesa_assembly.fasta"
        elif "megahit" in tools:
            return f"data/work/{wildcards.run_id}/04_assembly/{wildcards.sample_id}_megahit_assembly.fasta"
        else:
            return f"data/work/{wildcards.run_id}/04_assembly/{wildcards.sample_id}_short_assembly.fasta" # spades default

rule link_assembly:
    input:
        get_final_assembly
    output:
        "data/work/{run_id}/04_assembly/final/{sample_id}_assembly.fasta"
    shell:
        """
        cp {input} {output}
        """
