FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    pkg-config \
    libfreetype6-dev \
    libpng-dev \
    zlib1g-dev \
    perl \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir quast

ENTRYPOINT ["quast.py"]
