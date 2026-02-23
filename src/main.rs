use clap::Parser;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Condvar, Mutex};
use std::thread;

const EXIT_SUCCESS: i32 = 0;
const EXIT_ERROR: i32 = 1;
const EXIT_FATAL: i32 = 2;
const PROTECTED_PATHS: [&str; 2] = ["C:\\", "C:/"];

#[derive(Parser, Debug)]
#[command(name = "rmf", about = "Fast parallel recursive file deletion", version)]
struct Args {
    #[arg(required = true, help = "Target path(s) to delete")]
    targets: Vec<PathBuf>,

    #[arg(
        short,
        long,
        help = "Override safety guards (allow deleting protected paths)"
    )]
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

    if canonical == Path::new("/") {
        return true;
    }

    let path_str = canonical.to_string_lossy();

    if cfg!(target_os = "windows") {
        return PROTECTED_PATHS
            .iter()
            .any(|p| path_str.eq_ignore_ascii_case(p));
    }

    let home = get_home_dir();
    if let Ok(home_canonical) = fs::canonicalize(&home) {
        if canonical == home_canonical {
            return true;
        }
    }

    false
}

fn is_force_protected_path(path: &Path) -> bool {
    let canonical = match fs::canonicalize(path) {
        Ok(p) => p,
        Err(_) => return false,
    };

    if canonical == Path::new("/") {
        return true;
    }

    if cfg!(target_os = "windows") {
        let canonical_str = canonical.to_string_lossy();
        let protected = ["C:\\", "C:/"];
        return protected
            .iter()
            .any(|p| canonical_str.eq_ignore_ascii_case(p));
    }

    false
}

struct WorkQueue<T> {
    queue: Mutex<Vec<T>>,
    condvar: Condvar,
    done: AtomicBool,
}

impl<T> WorkQueue<T> {
    fn new() -> Self {
        Self {
            queue: Mutex::new(Vec::new()),
            condvar: Condvar::new(),
            done: AtomicBool::new(false),
        }
    }

    fn push(&self, item: T) {
        let mut q = self.queue.lock().unwrap();
        q.push(item);
        self.condvar.notify_one();
    }

    fn push_many(&self, items: Vec<T>) {
        if items.is_empty() {
            return;
        }
        let mut q = self.queue.lock().unwrap();
        q.extend(items);
        self.condvar.notify_all();
    }

    fn pop(&self) -> Option<T> {
        let mut q = self.queue.lock().unwrap();
        loop {
            if let Some(item) = q.pop() {
                return Some(item);
            }
            if self.done.load(Ordering::SeqCst) {
                return None;
            }
            q = self.condvar.wait(q).unwrap();
        }
    }

    fn signal_done(&self) {
        self.done.store(true, Ordering::SeqCst);
        self.condvar.notify_all();
    }
}

#[derive(Clone, Eq, PartialEq)]
struct DeferredDir {
    path: PathBuf,
    depth: usize,
}

impl Ord for DeferredDir {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.depth.cmp(&other.depth)
    }
}

impl PartialOrd for DeferredDir {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

#[derive(Default)]
struct LocalStats {
    files_deleted: usize,
    dirs_deleted: usize,
    failures: usize,
}

struct WorkerResult {
    deferred_dirs: Vec<DeferredDir>,
    stats: LocalStats,
}

fn delete_fast(target: &Path, num_threads: usize, quiet: bool) -> i32 {
    let queue: Arc<WorkQueue<(PathBuf, usize)>> = Arc::new(WorkQueue::new());
    let pending_jobs = Arc::new(AtomicUsize::new(1));
    let root: Arc<PathBuf> = Arc::new(target.to_path_buf());

    let mut handles = Vec::with_capacity(num_threads);

    for _ in 0..num_threads {
        let queue = Arc::clone(&queue);
        let pending_jobs = Arc::clone(&pending_jobs);
        let root = Arc::clone(&root);

        let handle = thread::spawn(move || {
            let mut deferred_dirs = Vec::new();
            let mut stats = LocalStats::default();
            while let Some((path, depth)) = queue.pop() {
                process_directory(
                    &path,
                    depth,
                    &queue,
                    &mut deferred_dirs,
                    &mut stats,
                    &pending_jobs,
                    &root,
                    quiet,
                );
            }
            WorkerResult {
                deferred_dirs,
                stats,
            }
        });
        handles.push(handle);
    }

    queue.push((target.to_path_buf(), 0usize));

    let pending_clone = Arc::clone(&pending_jobs);
    while pending_clone.load(Ordering::SeqCst) > 0 {
        std::thread::sleep(std::time::Duration::from_millis(1));
    }
    queue.signal_done();

    let mut deferred = Vec::new();
    let mut stats = LocalStats::default();

    for handle in handles {
        let result = handle.join().unwrap();
        deferred.extend(result.deferred_dirs);
        stats.files_deleted += result.stats.files_deleted;
        stats.dirs_deleted += result.stats.dirs_deleted;
        stats.failures += result.stats.failures;
    }

    deferred.sort_unstable_by(|a, b| b.depth.cmp(&a.depth));

    for DeferredDir { path, .. } in deferred {
        if let Err(e) = fs::remove_dir(&path) {
            stats.failures += 1;
            if !quiet {
                eprintln!("Failed to remove dir {}: {}", path.display(), e);
            }
        } else {
            stats.dirs_deleted += 1;
        }
    }

    let failures = stats.failures;
    if !quiet {
        let files = stats.files_deleted;
        let dirs = stats.dirs_deleted;
        eprintln!(
            "{} files deleted, {} directories ({} failures)",
            files, dirs, failures
        );
    }

    if failures > 0 {
        EXIT_ERROR
    } else {
        EXIT_SUCCESS
    }
}

#[allow(clippy::too_many_arguments)]
fn process_directory(
    path: &Path,
    depth: usize,
    queue: &WorkQueue<(PathBuf, usize)>,
    deferred_dirs: &mut Vec<DeferredDir>,
    stats: &mut LocalStats,
    pending_jobs: &AtomicUsize,
    root: &Path,
    quiet: bool,
) {
    let read_dir = match fs::read_dir(path) {
        Ok(rd) => rd,
        Err(e) => {
            stats.failures += 1;
            if !quiet {
                eprintln!("Failed to read dir {}: {}", path.display(), e);
            }
            pending_jobs.fetch_sub(1, Ordering::SeqCst);
            return;
        }
    };

    let mut subdirs = Vec::new();

    for entry in read_dir {
        let entry = match entry {
            Ok(e) => e,
            Err(_) => continue,
        };

        let entry_type = match entry.file_type() {
            Ok(t) => t,
            Err(_) => continue,
        };

        let entry_path = entry.path();

        if entry_type.is_symlink() {
            if let Err(e) = fs::remove_file(&entry_path) {
                stats.failures += 1;
                if !quiet {
                    eprintln!("Failed to remove symlink {}: {}", entry_path.display(), e);
                }
            } else {
                stats.files_deleted += 1;
            }
            continue;
        }

        if entry_type.is_dir() {
            subdirs.push((entry_path, depth + 1));
        } else {
            if let Err(e) = fs::remove_file(&entry_path) {
                stats.failures += 1;
                if !quiet {
                    eprintln!("Failed to delete file {}: {}", entry_path.display(), e);
                }
            } else {
                stats.files_deleted += 1;
            }
        }
    }

    let has_subdirs = !subdirs.is_empty();
    if has_subdirs {
        pending_jobs.fetch_add(subdirs.len(), Ordering::SeqCst);
        queue.push_many(subdirs);
    }

    if path == root || has_subdirs {
        deferred_dirs.push(DeferredDir {
            path: path.to_path_buf(),
            depth,
        });
    } else if let Err(e) = fs::remove_dir(path) {
        stats.failures += 1;
        if !quiet {
            eprintln!("Failed to remove dir {}: {}", path.display(), e);
        }
    } else {
        stats.dirs_deleted += 1;
    }

    pending_jobs.fetch_sub(1, Ordering::SeqCst);
}

fn delete_target(target: &Path, threads: usize, use_trash: bool, quiet: bool, force: bool) -> i32 {
    if !target.exists() {
        if !force {
            eprintln!("Error: Path does not exist: {}", target.display());
            return EXIT_FATAL;
        }
        return EXIT_SUCCESS;
    }

    if is_force_protected_path(target) {
        eprintln!(
            "Error: Refusing to delete root directory '{}'.",
            target.display()
        );
        return EXIT_FATAL;
    }

    if is_protected_path(target) && !force {
        eprintln!(
            "Error: Refusing to delete protected path '{}'. Use --force to override.",
            target.display()
        );
        return EXIT_FATAL;
    }

    if use_trash {
        if !quiet {
            eprintln!("Moving '{}' to trash...", target.display());
        }
        match trash::delete(target) {
            Ok(()) => return EXIT_SUCCESS,
            Err(e) => {
                eprintln!("Error moving to trash: {}", e);
                return EXIT_ERROR;
            }
        }
    }

    if !quiet {
        eprintln!(
            "Deleting '{}' with {} threads...",
            target.display(),
            threads
        );
    }

    let metadata = match fs::symlink_metadata(target) {
        Ok(m) => m,
        Err(e) => {
            eprintln!("Error reading metadata: {}", e);
            return EXIT_FATAL;
        }
    };

    if metadata.is_file() || metadata.is_symlink() {
        if let Err(e) = fs::remove_file(target) {
            eprintln!("Error deleting file: {}", e);
            return EXIT_ERROR;
        }
        if !quiet {
            eprintln!("1 files deleted, 0 directories (0 failures)");
        }
        return EXIT_SUCCESS;
    }

    delete_fast(target, threads, quiet)
}

fn main() -> ! {
    let args = Args::parse();

    let threads = args
        .threads
        .unwrap_or_else(|| {
            let total = num_cpus::get();
            ((total as f64 * 0.8).floor() as usize).max(1)
        })
        .clamp(1, 256);

    if !args.quiet {
        eprintln!("Using {} thread(s)", threads);
    }

    let mut has_partial_failure = false;
    let mut has_fatal_error = false;

    for target in &args.targets {
        let exit_code = delete_target(target, threads, args.trash, args.quiet, args.force);
        match exit_code {
            EXIT_ERROR => has_partial_failure = true,
            EXIT_FATAL => {
                if args.force {
                    has_partial_failure = true;
                } else {
                    has_fatal_error = true;
                }
            }
            _ => {}
        }
    }

    if has_fatal_error {
        std::process::exit(EXIT_FATAL);
    }
    if has_partial_failure {
        std::process::exit(EXIT_ERROR);
    }
    std::process::exit(EXIT_SUCCESS)
}
