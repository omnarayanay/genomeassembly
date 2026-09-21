FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    zlib1g-dev \
    flye \
    && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["flye"]
