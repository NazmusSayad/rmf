alias b := build
alias t := test
alias r := release

default: build

build:
    cargo build

release:
    cargo build --release

test:
    cargo test

clippy:
    cargo clippy -- -D warnings

fmt:
    cargo fmt -- --check

fmt-fix:
    cargo fmt

clean:
    cargo clean

docker-build:
    docker build -t rmf-test .

docker-shell: docker-build
    docker run --rm -it rmf-test bash

docker-test: docker-build
    docker run --rm rmf-test

docker-benchmark: docker-build
    MSYS_NO_PATHCONV=1 docker run --rm rmf-test bash //scripts/benchmark.sh

docker-hyperfine: docker-build
    MSYS_NO_PATHCONV=1 docker run --rm rmf-test bash //scripts/benchmark.sh --hyperfine

docker-bench files="100000": docker-build
    MSYS_NO_PATHCONV=1 docker run --rm rmf-test bash -c "//scripts/generate-test-data.sh {{files}} /test/bench && /usr/bin/time -v rmf --force /test/bench"

install: release
    cargo install --path .

check: fmt clippy test

ci: check release
