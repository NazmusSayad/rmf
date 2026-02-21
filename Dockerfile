FROM rust:1.93-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml ./
COPY src ./src

RUN cargo build --release

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    time \
    coreutils \
    sed \
    procps \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://github.com/sharkdp/hyperfine/releases/download/v1.19.0/hyperfine_1.19.0_amd64.deb \
    && dpkg -i hyperfine_1.19.0_amd64.deb \
    && rm hyperfine_1.19.0_amd64.deb

COPY --from=builder /app/target/release/rmf /usr/local/bin/rmf

WORKDIR /test

COPY scripts/ /scripts/
RUN sed -i 's/\r$//' /scripts/*.sh && chmod +x /scripts/*.sh

CMD ["/bin/bash", "/scripts/run-tests.sh"]
