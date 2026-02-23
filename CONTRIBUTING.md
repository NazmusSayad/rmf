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

## Architecture

`rmf` uses a work-stealing thread pool over a shared `WorkQueue<(PathBuf, depth)>`.

**Deletion strategy:**

1. Worker threads read directory entries and immediately delete files and symlinks.
2. Subdirectories are pushed back onto the queue for parallel traversal.
3. Directories are not removed inline — they are collected into a `deferred_dirs` list.
4. After all workers finish, deferred directories are sorted by depth (deepest first) using a `BinaryHeap` and removed sequentially. This avoids `ENOTEMPTY` errors.

**Key types:**

| Type           | Role                                                                         |
| -------------- | ---------------------------------------------------------------------------- |
| `WorkQueue<T>` | Mutex + Condvar-based MPMC queue; `signal_done` unblocks all waiting workers |
| `DeferredDir`  | Holds a path and its depth; `Ord` impl sorts deepest-first                   |
| `DeleteStats`  | Atomic counters for files, dirs, and failures                                |

**Safety checks** (`is_protected_path`, `is_force_protected_path`) canonicalize the path before comparing, so symlinks and relative paths cannot bypass them.

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
just docker-test       # full integration suite in isolated Linux container
just docker-benchmark  # performance benchmark: rmf vs rm -rf
```

**Why Docker tests?** They provide a clean, reproducible Linux environment to test edge cases (empty dirs, symlinks, nested trees, protected path rejection) that may behave differently on your local machine. This is especially important for cross-platform correctness.

**Docker setup:** Ensure Docker is installed and running. The tests use the container image defined in `Dockerfile` and run `scripts/run-tests.sh` inside it.

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

## Code Style

- `cargo fmt` is enforced in CI.
- `cargo clippy -- -D warnings` is enforced in CI. Fix all warnings before opening a PR.
- No `unsafe`. No `unwrap` on user-facing paths — use proper error propagation or `eprintln!` + early return.
