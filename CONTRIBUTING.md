# Contributing

## Prerequisites

- Rust stable (via [rustup](https://rustup.rs))
- [just](https://github.com/casey/just) — task runner
- Docker — for cross-platform test runs and isolated Linux environments (optional but recommended)

## Setup

```bash
git clone <repo>
cd rmf
cargo build
```

## Workflow

```bash
just build          # debug build
just test           # run tests
just check          # fmt + clippy + test (run before pushing)
just fmt-fix        # auto-format
```

All CI checks must pass before a PR is merged. Run `just check` locally first.

## Adding a Feature

- Keep the single-file structure (`src/main.rs`) unless the change genuinely warrants a module split.
- New CLI flags go in `Args`; document them in `README.md`.
- If the change affects deletion behavior, add a test in `cargo test` and verify with `just docker-test`.

## Testing

### Local Tests

```bash
just test              # unit tests and basic functionality
just fmt-check         # formatting check
just clippy            # linting
```

### Docker Tests (Recommended Before PR)

```bash
just docker-test      # full integration suite in isolated Linux container
just docker-bench-*   # performance benchmarks, defined in justfile
```

**Why Docker tests?** They provide a clean, reproducible Linux environment to test edge cases (empty dirs, symlinks, nested trees, protected path rejection) that may behave differently on your local machine. This is especially important for cross-platform correctness.

## Releases

Releases are automated via `.github/workflows/release.yml`. Push a `v*` tag to trigger a build for all supported targets and publish a GitHub Release with attached binaries.

```bash
git tag v0.2.0
git push origin v0.2.0
```

Targets built:

- `x86_64-unknown-linux-gnu`
- `x86_64-unknown-linux-musl`
- `aarch64-unknown-linux-gnu`
- `aarch64-unknown-linux-musl`
- `x86_64-apple-darwin`
- `aarch64-apple-darwin`
- `x86_64-pc-windows-msvc`
- `aarch64-pc-windows-msvc`
