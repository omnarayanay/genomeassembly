import urllib.request, json
repos = ['biocontainers/fastq-screen', 'biocontainers/ragtag', 'biocontainers/nanofilt', 'biocontainers/fastq_screen']

for r in repos:
    try:
        url = f'https://registry.hub.docker.com/v2/repositories/{r}/tags/?page_size=3'
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            print(f"{r}: {[t['name'] for t in data.get('results', [])]}")
    except Exception as e:
        print(f"{r}: {e}")

