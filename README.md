# rmf

Fast parallel recursive file deletion. A drop-in replacement for `rm -rf` that uses a thread pool to delete directory trees concurrently.

## Installation

**From source** (requires Rust):

```bash
cargo install --path .
```

**Pre-built binaries** are available on the [Releases](https://github.com/NazmusSayad/rmf/releases) page for Linux (x86_64, aarch64, musl), macOS (x86_64, Apple Silicon), and Windows (x86_64, ARM64).

## Usage

```
rmf [OPTIONS] <TARGETS>...

Arguments:
  <TARGETS>              One or more paths to delete

Options:
  -f, --force            Override safety guards (allow deleting protected paths)
      --threads <N>      Number of worker threads [default: number of logical CPUs]
  -q, --quiet            Suppress all output except errors
      --trash            Move to system trash instead of permanent deletion
  -h, --help             Print help
  -V, --version          Print version
```

## Examples

```bash
rmf ./node_modules

rmf --threads 8 ./target ./build ./dist

rmf --trash ./old-project

rmf -q ./large-directory
```

## Safety

By default, `rmf` includes built-in safeguards:

- **Filesystem root** — Cannot be deleted (even with `--force`)
- **Home directory** — Blocked by default; use `--force` to override

These checks are performed after path canonicalization, preventing bypasses via symlinks or relative paths.

## Exit Codes

| Code | Meaning                                      |
| ---- | -------------------------------------------- |
| `0`  | All targets deleted successfully             |
| `1`  | One or more files failed to delete           |
| `2`  | Fatal error (protected path, path not found) |

## License

MIT
