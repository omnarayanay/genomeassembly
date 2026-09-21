import json
import argparse
import sys

def parse_quast(quast_file):
    # Dummy parsing for scaffolding
    return {"N50": 50000, "L50": 2, "Total_length": 5000000}

def parse_busco(busco_file):
    # Dummy parsing for scaffolding
    return {"Complete": 95.0, "Missing": 5.0}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--quast", nargs='+', required=True)
    parser.add_argument("--busco", nargs='+', required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--min-n50", type=int, default=10000)
    args = parser.parse_args()

    metrics = {}
    
    # Process QUAST
    for q in args.quast:
        sample = q.split('/')[-1].replace('_report.tsv', '')
        metrics.setdefault(sample, {})
        metrics[sample]['quast'] = parse_quast(q)
        
        # QC Gate: N50
        if metrics[sample]['quast']['N50'] < args.min_n50:
            print(f"QC FAILED: {sample} N50 ({metrics[sample]['quast']['N50']}) is below threshold ({args.min_n50})", file=sys.stderr)
            sys.exit(1)

    # Process BUSCO
    for b in args.busco:
        sample = b.split('/')[-1].replace('_short_summary.txt', '')
        metrics.setdefault(sample, {})
        metrics[sample]['busco'] = parse_busco(b)

    summary = {
        "status": "done",
        "metrics": metrics
    }

    with open(args.output, "w") as f:
        json.dump(summary, f, indent=4)

if __name__ == "__main__":
    main()
