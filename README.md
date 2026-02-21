# rmf

Fast parallel recursive file deletion tool.

## Features

- Multi-threaded deletion for improved performance on large directories
- Safety guards against deleting protected paths (root, home directory)
- Optional trash mode for safer deletion
- Cross-platform support (Windows, Linux, macOS)

## Installation

```bash
just install
```

## Usage

```
rmf [OPTIONS] <TARGETS>...

Arguments:
  <TARGETS>  Target path(s) to delete

Options:
  -f, --force         Override safety guards (allow deleting protected paths)
      --threads <N>   Number of worker threads [default: CPU count]
  -q, --quiet         Suppress non-error output
      --trash         Move to trash instead of permanent delete
  -h, --help          Print help
  -V, --version       Print version
```

## Examples

```bash
# Delete a directory using all CPU cores
rmf ./node_modules

# Delete multiple paths with 8 threads
rmf --threads 8 ./target ./build ./dist

# Move to trash instead of deleting
rmf --trash ./old-project

# Quiet mode (only show errors)
rmf -q ./large-directory
```

## Development

```bash
# Build
just build

# Run tests
just test

# Lint
just clippy

# Format check
just fmt

# Format fix
just fmt-fix

# Full check (fmt + clippy + test)
just check
```

## License

MIT
