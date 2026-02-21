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

docker-test: docker-build
    docker run --rm rmf-test

docker-build:
    docker build -t rmf-test .

docker-shell: docker-build
    docker run --rm -it rmf-test bash

docker-benchmark: docker-build
    MSYS_NO_PATHCONV=1 docker run --rm rmf-test bash //scripts/benchmark.sh

docker-hyperfine: docker-build
    MSYS_NO_PATHCONV=1 docker run --rm rmf-test bash //scripts/benchmark.sh --hyperfine

docker-realworld: docker-build
    MSYS_NO_PATHCONV=1 docker run --rm rmf-test bash //scripts/realworld-benchmark.sh

install: release
    cargo install --path .

check: fmt clippy test

ci: check release
