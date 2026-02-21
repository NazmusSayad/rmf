# PRD — rmf (MVP)

## 1. Objective

Build a Rust CLI tool that deletes large directory trees faster than typical single-threaded deletion in developer workflows, while remaining safe by default.

MVP focuses strictly on high-performance recursive deletion on Unix-like systems.

---

## 2. Target Use Case

Primary scenario:

- Deleting large dependency or build directories (100k–1M+ small files).
- Running on SSD-backed filesystems.
- Invoked manually by developers or in CI cleanup steps.

Non-goal: replacing system `rm` for all use cases.

---

## 3. Functional Requirements (MVP)

### 3.1 Recursive Deletion

- Accept a single target path.
- Recursively delete all contents.
- Do not follow symlinks (delete the link only).
- Delete files before directories (bottom-up).

### 3.2 Parallel Deletion

- File deletions must be executed in parallel using a bounded thread pool.
- Default worker count = logical CPU cores.
- Configurable via `--threads <n>`.
- Thread count must be capped to prevent unbounded spawning.

### 3.3 Safety Rules

- Refuse to delete `/`.
- Refuse to delete user home directory unless `--force`.
- Require confirmation prompt unless `--force`.

### 3.4 CLI Contract

Usage:

```
rmf <target>
```

Flags:

- `--force` → skip confirmation.
- `--threads <n>` → override worker count.
- `--quiet` → suppress non-error output.

Only one target path supported in MVP.

---

## 4. Non-Functional Requirements

### 4.1 Performance

- Must handle 500k–1M small files without crashing.
- Must not load the entire directory tree into memory at once.
- Memory usage should scale with traversal window, not total file count.

### 4.2 Behavior Under Errors

- Continue deleting remaining entries if individual deletions fail.
- Report total failures at end.

Exit codes:

- 0 → all entries deleted successfully.
- 1 → partial failure.
- 2 → invalid usage or fatal setup error.

---

## 5. Technical Constraints

- Implemented in stable Rust.
- Use streaming directory traversal (e.g., iterator-based walk).
- No async runtime in MVP.
- No background deletion mode.
- Unix-like systems only (Linux/macOS) for first release.

Deletion algorithm (MVP):

1. Traverse directory tree.
2. Dispatch file deletions to thread pool.
3. Track directories by depth.
4. Remove directories in reverse depth order after files complete.

---

## 6. Acceptance Criteria

- Successfully deletes a directory containing ≥1M empty files on SSD.
- Does not exceed reasonable memory bounds during test (no full-tree buffering).
- Refuses to delete `/` without override.
- Thread count flag correctly limits concurrency.
- Returns correct exit codes for success and partial failure.

---

## 7. Explicitly Out of Scope

- Windows support.
- Background rename-and-delete mode.
- Exclusion patterns.
- Progress bars.
- Secure wipe/shred.
- Trash/recycle-bin integration.
- Multiple targets per invocation.

Future features depend on benchmarking results and real-world feedback.
