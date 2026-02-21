FROM rust:1.93-slim

WORKDIR /app

RUN apt-get update -qq
RUN apt-get install -y -qq pkg-config time nodejs npm grep procps coreutils

COPY Cargo.toml ./
COPY src ./src

RUN cargo build --release --quiet

RUN cp target/release/rmf /usr/local/bin/rmf

WORKDIR /test

COPY scripts/ /scripts/
RUN sed -i 's/\r$//' /scripts/*.sh && chmod +x /scripts/*.sh

CMD ["/bin/bash", "/scripts/run-tests.sh"]
