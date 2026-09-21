FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    wget \
    fastp \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["fastp"]
