import gzip

def generate_dummy_fastq(filename, num_reads=1000):
    with gzip.open(filename, "wt") as f:
        for i in range(num_reads):
            # 100bp random sequence
            f.write(f"@read_{i}\n")
            f.write("A" * 25 + "C" * 25 + "G" * 25 + "T" * 25 + "\n")
            f.write("+\n")
            f.write("I" * 100 + "\n")

if __name__ == "__main__":
    generate_dummy_fastq("tests/fixtures/sample_01_R1.fastq.gz")
    generate_dummy_fastq("tests/fixtures/sample_01_R2.fastq.gz")
    generate_dummy_fastq("tests/fixtures/sample_01_long.fastq.gz", num_reads=500)
