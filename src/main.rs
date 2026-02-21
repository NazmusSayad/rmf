use clap::Parser;
use rayon::ThreadPool;
use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::io::{self, Write};
use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use walkdir::WalkDir;

#[derive(Parser)]
#[command(name = "rmf", about = "Fast parallel directory deletion tool")]
struct Args {
    #[arg(help = "Target path to delete")]
    target: PathBuf,

    #[arg(long, help = "Skip confirmation prompt")]
    force: bool,

    #[arg(
        long,
        value_name = "N",
        help = "Number of threads (default: CPU cores)"
    )]
    threads: Option<usize>,

    #[arg(long, help = "Suppress non-error output")]
    quiet: bool,
}

const EXIT_SUCCESS: i32 = 0;
const EXIT_PARTIAL_FAILURE: i32 = 1;
const EXIT_FATAL: i32 = 2;

fn main() {
    let args = Args::parse();
    let exit_code = run(args);
    std::process::exit(exit_code);
}

fn run(args: Args) -> i32 {
    let target = match args.target.canonicalize() {
        Ok(p) => p,
        Err(e) => {
            eprintln!("rmf: cannot access '{}': {}", args.target.display(), e);
            return EXIT_FATAL;
        }
    };

    if let Some(msg) = check_safety(&target, args.force) {
        eprintln!("rmf: {}", msg);
        return EXIT_FATAL;
    }

    if !args.force {
        if !confirm(&target) {
            eprintln!("rmf: operation cancelled");
            return EXIT_FATAL;
        }
    }

    let thread_count = args.threads.unwrap_or_else(num_cpus::get);
    let thread_count = thread_count.max(1).min(256);

    let pool = match rayon::ThreadPoolBuilder::new()
        .num_threads(thread_count)
        .build()
    {
        Ok(p) => p,
        Err(e) => {
            eprintln!("rmf: failed to create thread pool: {}", e);
            return EXIT_FATAL;
        }
    };

    let failure_count = Arc::new(AtomicUsize::new(0));

    let (files, dirs) = collect_entries(&target, &failure_count, args.quiet);

    delete_files(&pool, files, &failure_count, args.quiet);
    delete_dirs(dirs, &failure_count, args.quiet);

    if let Err(e) = fs::remove_dir_all(&target) {
        if !args.quiet {
            eprintln!("rmf: failed to remove '{}': {}", target.display(), e);
        }
        failure_count.fetch_add(1, Ordering::Relaxed);
    }

    let failures = failure_count.load(Ordering::Relaxed);
    if failures > 0 && !args.quiet {
        eprintln!("rmf: {} operation(s) failed", failures);
    }

    if failures == 0 {
        EXIT_SUCCESS
    } else {
        EXIT_PARTIAL_FAILURE
    }
}

fn check_safety(path: &PathBuf, force: bool) -> Option<String> {
    let path_str = path.to_string_lossy();

    if path_str == "/" {
        return Some("refusing to delete root directory '/'".to_string());
    }

    if let Ok(home) = env::var("HOME") {
        if path_str == home && !force {
            return Some("refusing to delete home directory without --force".to_string());
        }
    }

    None
}

fn confirm(path: &PathBuf) -> bool {
    print!("rmf: delete '{}'? [y/N] ", path.display());
    io::stdout().flush().ok();

    let mut input = String::new();
    io::stdin().read_line(&mut input).ok();
    matches!(input.trim().to_lowercase().as_str(), "y" | "yes")
}

fn collect_entries(
    root: &PathBuf,
    failure_count: &Arc<AtomicUsize>,
    quiet: bool,
) -> (Vec<PathBuf>, BTreeMap<usize, Vec<PathBuf>>) {
    let mut files = Vec::new();
    let mut dirs: BTreeMap<usize, Vec<PathBuf>> = BTreeMap::new();

    for entry in WalkDir::new(root)
        .follow_links(false)
        .into_iter()
        .filter_map(|e| e.ok())
    {
        let path = entry.path().to_path_buf();
        let depth = entry.depth();

        let file_type = entry.file_type();

        if file_type.is_symlink() {
            files.push(path);
        } else if file_type.is_dir() {
            dirs.entry(depth).or_default().push(path);
        } else if file_type.is_file() {
            files.push(path);
        } else {
            failure_count.fetch_add(1, Ordering::Relaxed);
            if !quiet {
                eprintln!("rmf: skipping unknown file type: {}", path.display());
            }
        }
    }

    (files, dirs)
}

fn delete_files(
    pool: &ThreadPool,
    files: Vec<PathBuf>,
    failure_count: &Arc<AtomicUsize>,
    quiet: bool,
) {
    let failures = failure_count.clone();

    pool.install(|| {
        rayon::iter::IntoParallelIterator::into_par_iter(files).for_each(|path| {
            if let Err(e) = fs::remove_file(&path) {
                failures.fetch_add(1, Ordering::Relaxed);
                if !quiet {
                    eprintln!("rmf: failed to delete '{}': {}", path.display(), e);
                }
            }
        });
    });
}

fn delete_dirs(dirs: BTreeMap<usize, Vec<PathBuf>>, failure_count: &Arc<AtomicUsize>, quiet: bool) {
    let depths: Vec<usize> = dirs.keys().cloned().collect();

    for depth in depths.into_iter().rev() {
        if let Some(paths) = dirs.get(&depth) {
            for path in paths {
                if let Err(e) = fs::remove_dir(path) {
                    failure_count.fetch_add(1, Ordering::Relaxed);
                    if !quiet {
                        eprintln!("rmf: failed to remove directory: {}", e);
                    }
                }
            }
        }
    }
}
