import os
import glob
import re

pipeline_dir = r"c:\Users\Vishwajeet Maurya\Desktop\biotech\pipeline"
files = glob.glob(os.path.join(pipeline_dir, "**", "*.smk"), recursive=True)
files.append(os.path.join(pipeline_dir, "Snakefile"))

# Mapping of old directory patterns to new serialized directory patterns
replacements = {
    r"data/results/\{([^{}]+)\}/qc": r"data/results/{\1}/01_qc",
    r"data/work/\{([^{}]+)\}/trimmed": r"data/work/{\1}/02_trim",
    r"data/results/\{([^{}]+)\}/kraken": r"data/results/{\1}/03_screen/kraken",
    r"data/results/\{([^{}]+)\}/fastq_screen": r"data/results/{\1}/03_screen/fastq_screen",
    r"data/work/\{([^{}]+)\}/assembly_final": r"data/work/{\1}/04_assembly/final",
    r"data/work/\{([^{}]+)\}/assembly": r"data/work/{\1}/04_assembly",
    r"data/work/\{([^{}]+)\}/scaffold": r"data/work/{\1}/05_scaffold",
    r"data/results/\{([^{}]+)\}/quast": r"data/results/{\1}/06_validation/quast",
    r"data/results/\{([^{}]+)\}/busco": r"data/results/{\1}/06_validation/busco",
    r"data/results/\{([^{}]+)\}/annotation": r"data/results/{\1}/07_annotation/prokka",
    r"data/results/\{([^{}]+)\}/bakta": r"data/results/{\1}/07_annotation/bakta",
    r"data/results/\{([^{}]+)\}/dfast": r"data/results/{\1}/07_annotation/dfast",
    r"data/results/\{([^{}]+)\}/augustus": r"data/results/{\1}/07_annotation/augustus",
    r"data/results/\{([^{}]+)\}/funannotate": r"data/results/{\1}/07_annotation/funannotate",
    r"data/results/\{([^{}]+)\}/braker": r"data/results/{\1}/07_annotation/braker",
    r"data/results/\{([^{}]+)\}/repeatmasker": r"data/results/{\1}/07_annotation/repeatmasker",
    r"data/results/\{([^{}]+)\}/eggnog": r"data/results/{\1}/07_annotation/eggnog",
    r"data/results/\{([^{}]+)\}/interproscan": r"data/results/{\1}/07_annotation/interproscan",
    r"data/results/\{([^{}]+)\}/kofamscan": r"data/results/{\1}/07_annotation/kofamscan",
    r"data/results/\{([^{}]+)\}/dbcan": r"data/results/{\1}/07_annotation/dbcan",
    r"data/results/\{([^{}]+)\}/abricate": r"data/results/{\1}/07_annotation/abricate",
    r"data/results/\{([^{}]+)\}/amrfinder": r"data/results/{\1}/07_annotation/amrfinder",
    r"data/results/\{([^{}]+)\}/plasmidfinder": r"data/results/{\1}/07_annotation/plasmidfinder",
    r"data/results/\{([^{}]+)\}/phigaro": r"data/results/{\1}/07_annotation/phigaro",
    r"data/results/\{([^{}]+)\}/crisprcasfinder": r"data/results/{\1}/07_annotation/crisprcasfinder",
    r"data/results/\{([^{}]+)\}/antismash": r"data/results/{\1}/07_annotation/antismash",
    r"data/results/\{([^{}]+)\}/gtdbtk": r"data/results/{\1}/07_annotation/gtdbtk",
    r"data/results/\{([^{}]+)\}/roary": r"data/results/{\1}/07_annotation/roary",
    r"data/results/\{([^{}]+)\}/blastn": r"data/results/{\1}/08_identification/blastn",
    r"data/results/\{([^{}]+)\}/blastp": r"data/results/{\1}/08_identification/blastp",
    r"data/results/\{([^{}]+)\}/blastx": r"data/results/{\1}/08_identification/blastx",
    r"data/results/\{([^{}]+)\}/report": r"data/results/{\1}/09_report"
}

# Also handle cases where wildcards aren't used, e.g. hardcoded run_id or output paths
replacements_hard = {
    r"data/results/([^/]+)/qc": r"data/results/\1/01_qc",
    r"data/work/([^/]+)/trimmed": r"data/work/\1/02_trim",
    r"data/work/([^/]+)/assembly_final": r"data/work/\1/04_assembly/final",
    r"data/work/([^/]+)/assembly": r"data/work/\1/04_assembly",
    r"data/work/([^/]+)/scaffold": r"data/work/\1/05_scaffold",
    r"data/results/([^/]+)/quast": r"data/results/\1/06_validation/quast",
    r"data/results/([^/]+)/busco": r"data/results/\1/06_validation/busco",
    r"data/results/([^/]+)/annotation": r"data/results/\1/07_annotation/prokka",
    r"data/results/([^/]+)/abricate": r"data/results/\1/07_annotation/abricate",
    r"data/results/([^/]+)/report": r"data/results/\1/09_report",
}

for filepath in files:
    with open(filepath, 'r') as f:
        content = f.read()
    
    new_content = content
    for old, new in replacements.items():
        new_content = re.sub(old, new, new_content)
    
    # Check for wildcards.run_id specifically
    for old, new in replacements.items():
        o2 = old.replace(r"\{([^{}]+)\}", r"\{wildcards.run_id\}")
        n2 = new.replace(r"{\1}", r"{wildcards.run_id}")
        new_content = re.sub(o2, n2, new_content)
        
    for old, new in replacements.items():
        o2 = old.replace(r"\{([^{}]+)\}", r"\{run_id\}")
        n2 = new.replace(r"{\1}", r"{run_id}")
        new_content = re.sub(o2, n2, new_content)

    if new_content != content:
        with open(filepath, 'w') as f:
            f.write(new_content)
        print(f"Updated {filepath}")
