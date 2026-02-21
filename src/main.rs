use clap::Parser;
use indicatif::{ProgressBar, ProgressStyle};
use rayon::prelude::*;
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};

const EXIT_SUCCESS: i32 = 0;
const EXIT_PARTIAL_FAILURE: i32 = 1;
const EXIT_FATAL: i32 = 2;

#[derive(Parser, Debug)]
#[command(name = "rmf", about = "Fast parallel recursive file deletion", version)]
struct Args {
    #[arg(required = true, help = "Target path(s) to delete")]
    targets: Vec<PathBuf>,

    #[arg(short, long, help = "Skip confirmation prompt")]
    force: bool,

    #[arg(long, value_name = "N", help = "Number of worker threads")]
    threads: Option<usize>,

    #[arg(short, long, help = "Suppress non-error output")]
    quiet: bool,

    #[arg(long, help = "Move to trash instead of permanent delete")]
    trash: bool,
}

fn get_home_dir() -> PathBuf {
    dirs::home_dir().unwrap_or_else(|| PathBuf::from("/"))
}

fn is_protected_path(path: &Path) -> bool {
    let canonical = match fs::canonicalize(path) {
        Ok(p) => p,
        Err(_) => return false,
    };

    let path_str = canonical.to_string_lossy();

    if cfg!(target_os = "windows") {
        let protected = ["C:\\", "C:/"];
        return protected.iter().any(|p| path_str.eq_ignore_ascii_case(p));
    }

    if canonical == Path::new("/") {
        return true;
    }

    let home = get_home_dir();
    if let Ok(home_canonical) = fs::canonicalize(&home) {
        if canonical == home_canonical {
            return true;
        }
    }

    false
}

fn prompt_confirmation(path: &Path) -> bool {
    print!("Delete '{}' and all its contents? [y/N] ", path.display());
    io::stdout().flush().ok();

    let mut input = String::new();
    io::stdin().read_line(&mut input).ok();
    matches!(input.trim().to_lowercase().as_str(), "y" | "yes")
}

fn collect_entries(target: &Path) -> io::Result<Vec<(PathBuf, bool, usize)>> {
    let mut entries = Vec::new();
    let mut stack = vec![(target.to_path_buf(), 0usize)];

    while let Some((path, depth)) = stack.pop() {
        let metadata = match fs::symlink_metadata(&path) {
            Ok(m) => m,
            Err(_) => {
                entries.push((path, false, depth));
                continue;
            }
        };

        if metadata.is_symlink() {
            entries.push((path, false, depth));
            continue;
        }

        if metadata.is_dir() {
            let read_dir = match fs::read_dir(&path) {
                Ok(rd) => rd,
                Err(_) => {
                    entries.push((path, true, depth));
                    continue;
                }
            };

            for entry in read_dir {
                match entry {
                    Ok(e) => stack.push((e.path(), depth + 1)),
                    Err(_) => continue,
                }
            }
            entries.push((path, true, depth));
        } else {
            entries.push((path, false, depth));
        }
    }

    Ok(entries)
}

fn delete_entries_parallel(
    entries: Vec<(PathBuf, bool, usize)>,
    threads: usize,
    use_trash: bool,
    quiet: bool,
) -> usize {
    let pool = rayon::ThreadPoolBuilder::new()
        .num_threads(threads)
        .build()
        .unwrap();

    let failures = AtomicUsize::new(0);

    let files: Vec<_> = entries
        .iter()
        .filter(|(_, is_dir, _)| !is_dir)
        .cloned()
        .collect();

    let progress = if quiet {
        ProgressBar::hidden()
    } else {
        let pb = ProgressBar::new(files.len() as u64);
        pb.set_style(
            ProgressStyle::with_template("{spinner:.green} [{elapsed_precise}] [{bar:40.cyan/blue}] {pos}/{len} files deleted ({eta})")
                .unwrap()
                .progress_chars("#>-"),
        );
        pb
    };

    pool.install(|| {
        files.into_par_iter().for_each(|(path, _, _)| {
            let result = if use_trash {
                trash::delete(&path).map_err(io::Error::other)
            } else {
                fs::remove_file(&path)
            };

            if let Err(e) = result {
                failures.fetch_add(1, Ordering::Relaxed);
                if !quiet {
                    eprintln!("Failed to delete file: {}: {}", path.display(), e);
                }
            }

            progress.inc(1);
        });
    });

    let dirs: Vec<_> = entries
        .iter()
        .filter(|(_, is_dir, _)| *is_dir)
        .cloned()
        .collect();

    if !use_trash {
        let mut max_depth = 0;
        for (_, _, depth) in &dirs {
            if *depth > max_depth {
                max_depth = *depth;
            }
        }

        for depth in (0..=max_depth).rev() {
            let dirs_at_depth: Vec<_> = dirs
                .iter()
                .filter(|(_, _, d)| *d == depth)
                .map(|(p, _, _)| p.clone())
                .collect();

            for dir in dirs_at_depth {
                if !quiet {
                    progress.set_message(format!("Removing dir: {}", dir.display()));
                }
                if fs::remove_dir(&dir).is_err() {
                    failures.fetch_add(1, Ordering::Relaxed);
                }
            }
        }
    } else {
        let root_dirs: Vec<_> = dirs
            .iter()
            .filter(|(_, is_dir, _)| *is_dir)
            .map(|(p, _, _)| p.clone())
            .collect();

        for dir in root_dirs {
            if trash::delete(&dir).is_err() {
                failures.fetch_add(1, Ordering::Relaxed);
            }
        }
    }

    if !quiet {
        progress.finish();
    }

    failures.load(Ordering::Relaxed)
}

fn delete_target(target: &Path, threads: usize, use_trash: bool, quiet: bool, force: bool) -> i32 {
    if !target.exists() {
        eprintln!("Error: Path does not exist: {}", target.display());
        return EXIT_FATAL;
    }

    if is_protected_path(target) && !force {
        eprintln!(
            "Error: Refusing to delete protected path '{}'. Use --force to override.",
            target.display()
        );
        return EXIT_FATAL;
    }

    if !force && !quiet && !prompt_confirmation(target) {
        eprintln!("Aborted.");
        return EXIT_SUCCESS;
    }

    if use_trash {
        if !quiet {
            eprintln!("Moving '{}' to trash...", target.display());
        }
        match trash::delete(target) {
            Ok(()) => return EXIT_SUCCESS,
            Err(e) => {
                eprintln!("Error moving to trash: {}", e);
                return EXIT_PARTIAL_FAILURE;
            }
        }
    }

    if !quiet {
        eprintln!("Scanning '{}'...", target.display());
    }

    let entries = match collect_entries(target) {
        Ok(e) => e,
        Err(e) => {
            eprintln!("Error scanning directory: {}", e);
            return EXIT_FATAL;
        }
    };

    if entries.is_empty() {
        return EXIT_SUCCESS;
    }

    let file_count = entries.iter().filter(|(_, is_dir, _)| !is_dir).count();
    let dir_count = entries.iter().filter(|(_, is_dir, _)| *is_dir).count();

    if !quiet {
        eprintln!(
            "Found {} files and {} directories in '{}'",
            file_count,
            dir_count,
            target.display()
        );
    }

    let failures = delete_entries_parallel(entries, threads, false, quiet);

    if failures > 0 {
        if !quiet {
            eprintln!(
                "'{}' completed with {} failure(s)",
                target.display(),
                failures
            );
        }
        return EXIT_PARTIAL_FAILURE;
    }

    EXIT_SUCCESS
}

fn main() -> ! {
    let args = Args::parse();

    let threads = args.threads.unwrap_or_else(num_cpus::get).clamp(1, 256);

    if !args.quiet {
        eprintln!("Using {} thread(s)", threads);
    }

    let mut has_partial_failure = false;
    let mut has_fatal_error = false;

    for target in &args.targets {
        let exit_code = delete_target(target, threads, args.trash, args.quiet, args.force);
        match exit_code {
            EXIT_PARTIAL_FAILURE => has_partial_failure = true,
            EXIT_FATAL => has_fatal_error = true,
            _ => {}
        }
    }

    if has_fatal_error {
        std::process::exit(EXIT_FATAL);
    }
    if has_partial_failure {
        std::process::exit(EXIT_PARTIAL_FAILURE);
    }
    std::process::exit(EXIT_SUCCESS);
}
