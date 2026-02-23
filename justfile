alias b := build
alias t := test
alias r := release

default: build

docker_image := "rmf-test"

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
    docker build -q -t {{docker_image}} .

docker-test: docker-build
    MSYS_NO_PATHCONV=1 docker run --rm {{docker_image}} bash //scripts/run-tests.sh

docker-bench-basic: docker-build
    MSYS_NO_PATHCONV=1 docker run --rm {{docker_image}} bash //scripts/benchmark/basic.sh

docker-bench-rm: docker-build
    MSYS_NO_PATHCONV=1 docker run --rm {{docker_image}} bash //scripts/benchmark/rm.sh

docker-bench-real: docker-build
    MSYS_NO_PATHCONV=1 docker run --rm {{docker_image}} bash //scripts/benchmark/real-projects.sh

docker-bench-force: docker-build
    MSYS_NO_PATHCONV=1 docker run --rm {{docker_image}} bash //scripts/benchmark/flag-force.sh

install: release
    cargo install --path .

check: fmt clippy test

ci: check release
