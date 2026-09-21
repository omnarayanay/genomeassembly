def get_fastp_input(wildcards):
    s = SAMPLE_DICT[wildcards.sample_id]
    reads = {"r1": s.get("read1")}
    if s.get("read2"):
        reads["r2"] = s.get("read2")
    return reads

rule fastp_trim:
    input:
        unpack(get_fastp_input)
    output:
        trimmed="data/work/{run_id}/02_trim/{sample_id}_fastp_trimmed.fastq.gz",
        html="data/results/{run_id}/trim/{sample_id}_fastp.html",
        json="data/results/{run_id}/trim/{sample_id}_fastp.json"
    container:
        "docker://staphb/fastp:0.23.4"
    threads: config.get("resources", {}).get("threads", 4)
    resources:
        mem_mb=config.get("resources", {}).get("mem_mb", 4096)
    params:
        r2 = lambda w, input: input.r2 if hasattr(input, "r2") else ""
    shell:
        """
        if [ "{params.r2}" != "" ]; then
            fastp -i {input.r1} -I {params.r2} --stdout -h {output.html} -j {output.json} -w {threads} | gzip > {output.trimmed}
        else
            fastp -i {input.r1} -o {output.trimmed} -h {output.html} -j {output.json} -w {threads}
        fi
        """

rule nanofilt_trim:
    input:
        get_long_reads
    output:
        "data/work/{run_id}/02_trim/{sample_id}_nanofilt.fastq.gz"
    container:
        "docker://staphb/nanofilt:2.8.0"
    shell:
        """
        gunzip -c {input} | NanoFilt -q 10 -l 500 | gzip > {output}
        """

rule chopper_trim:
    input:
        "data/work/{run_id}/02_trim/{sample_id}_nanofilt.fastq.gz"
    output:
        "data/work/{run_id}/02_trim/{sample_id}_chopper_trimmed.fastq.gz"
    container:
        "docker://quay.io/biocontainers/chopper:0.7.0--hd03093a_0"
    threads: config.get("resources", {}).get("threads", 4)
    shell:
        """
        gunzip -c {input} | chopper -q 10 -l 500 --threads {threads} | gzip > {output}
        """

def get_final_trimmed(wildcards):
    s = SAMPLE_DICT[wildcards.sample_id]
    if s.get("read_type") in ["long", "hybrid"]:
        return f"data/work/{wildcards.run_id}/02_trim/{wildcards.sample_id}_chopper_trimmed.fastq.gz"
    else:
        return f"data/work/{wildcards.run_id}/02_trim/{wildcards.sample_id}_fastp_trimmed.fastq.gz"

rule link_trimmed:
    input:
        get_final_trimmed
    output:
        "data/work/{run_id}/02_trim_final/{sample_id}_trimmed.fastq.gz"
    shell:
        """
        cp {input} {output}
        """
