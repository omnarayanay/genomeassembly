def get_reference(wildcards):
    for s in SAMPLES:
        if s["sample_id"] == wildcards.sample_id:
            return s.get("reference") or []
    return []

rule scaffold_ragtag:
    input:
        assembly="data/work/{run_id}/04_assembly/final/{sample_id}_assembly.fasta",
        reference=get_reference
    output:
        scaffold="data/work/{run_id}/05_scaffold/{sample_id}_scaffold.fasta"
    # container:
    #     "docker://staphb/ragtag:2.1.0"
    threads: config.get("resources", {}).get("threads", 4)
    resources:
        mem_mb=config.get("resources", {}).get("mem_mb", 8192)
    shell:
        """
        if [ ! -z "{input.reference}" ]; then
            ragtag.py scaffold {input.reference} {input.assembly} -o data/work/{wildcards.run_id}/05_scaffold_out -t {threads}
            cp data/work/{wildcards.run_id}/05_scaffold_out/ragtag.scaffold.fasta {output.scaffold}
        else
            echo "No reference found, skipping scaffolding."
            cp {input.assembly} {output.scaffold}
        fi
        """
