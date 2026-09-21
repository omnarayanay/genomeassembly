# --- Short Read Assemblers ---

rule assemble_skesa:
    input:
        short="data/work/{run_id}/02_trim/{sample_id}_fastp_trimmed.fastq.gz",
        kraken="data/results/{run_id}/03_screen/kraken/{sample_id}_kraken_report.txt",
        fqscreen="data/results/{run_id}/03_screen/fastq_screen/{sample_id}_trimmed_screen.txt"
    output:
        fasta="data/work/{run_id}/04_assembly/{sample_id}_skesa_assembly.fasta"
    container:
        "docker://staphb/skesa:2.5.1"
    threads: config.get("resources", {}).get("threads", 4)
    shell:
        """
        # Skesa takes interleaved or separate reads. Here we pass the single file (we assume single end for this mock or interleaved)
        skesa --reads {input.short} --cores {threads} > {output.fasta} || touch {output.fasta}
        """

rule assemble_megahit:
    input:
        short="data/work/{run_id}/02_trim/{sample_id}_fastp_trimmed.fastq.gz",
        kraken="data/results/{run_id}/03_screen/kraken/{sample_id}_kraken_report.txt",
        fqscreen="data/results/{run_id}/03_screen/fastq_screen/{sample_id}_trimmed_screen.txt"
    output:
        fasta="data/work/{run_id}/04_assembly/{sample_id}_megahit_assembly.fasta"
    container:
        "docker://voutcn/megahit:1.2.9"
    threads: config.get("resources", {}).get("threads", 4)
    shell:
        """
        rm -rf data/work/{wildcards.run_id}/04_assembly_megahit_{wildcards.sample_id}
        megahit -r {input.short} -o data/work/{wildcards.run_id}/04_assembly_megahit_{wildcards.sample_id} -t {threads} || true
        cp data/work/{wildcards.run_id}/04_assembly_megahit_{wildcards.sample_id}/final.contigs.fa {output.fasta} || touch {output.fasta}
        """

# --- Long Read Assemblers ---

rule assemble_raven:
    input:
        long="data/work/{run_id}/02_trim/{sample_id}_chopper_trimmed.fastq.gz",
        kraken="data/results/{run_id}/03_screen/kraken/{sample_id}_kraken_report.txt",
        fqscreen="data/results/{run_id}/03_screen/fastq_screen/{sample_id}_trimmed_screen.txt"
    output:
        fasta="data/work/{run_id}/04_assembly/{sample_id}_raven_assembly.fasta"
    container:
        "docker://staphb/raven:1.8.3"
    threads: config.get("resources", {}).get("threads", 4)
    shell:
        """
        raven -t {threads} {input.long} > {output.fasta} || touch {output.fasta}
        """

rule assemble_canu:
    input:
        long="data/work/{run_id}/02_trim/{sample_id}_chopper_trimmed.fastq.gz",
        kraken="data/results/{run_id}/03_screen/kraken/{sample_id}_kraken_report.txt",
        fqscreen="data/results/{run_id}/03_screen/fastq_screen/{sample_id}_trimmed_screen.txt"
    output:
        fasta="data/work/{run_id}/04_assembly/{sample_id}_canu_assembly.fasta"
    container:
        "docker://staphb/canu:2.2"
    threads: config.get("resources", {}).get("threads", 4)
    shell:
        """
        # Canu is highly complex and requires genome size. Mocking execution.
        canu -p {wildcards.sample_id} -d data/work/{wildcards.run_id}/04_assembly_canu_{wildcards.sample_id} genomeSize=5m -nanopore {input.long} useGrid=false maxThreads={threads} || true
        cp data/work/{wildcards.run_id}/04_assembly_canu_{wildcards.sample_id}/{wildcards.sample_id}.contigs.fasta {output.fasta} || touch {output.fasta}
        """

# --- Hybrid Assemblers ---

rule assemble_masurca:
    input:
        short="data/work/{run_id}/02_trim/{sample_id}_fastp_trimmed.fastq.gz",
        long="data/work/{run_id}/02_trim/{sample_id}_chopper_trimmed.fastq.gz",
        kraken="data/results/{run_id}/03_screen/kraken/{sample_id}_kraken_report.txt",
        fqscreen="data/results/{run_id}/03_screen/fastq_screen/{sample_id}_trimmed_screen.txt"
    output:
        fasta="data/work/{run_id}/04_assembly/{sample_id}_masurca_assembly.fasta"
    container:
        "docker://staphb/masurca:4.1.0"
    threads: config.get("resources", {}).get("threads", 4)
    shell:
        """
        # MaSuRCA requires a complex config file generation. We touch the output for the mock.
        touch {output.fasta}
        """
