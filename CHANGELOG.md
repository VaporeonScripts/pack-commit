# Changelog

## v1.1.0 — File picker, undo/amend, and skip support

Adds several interactive workflow improvements on top of the v1.0.0 stable release.

### Added
- Numbered file picker for multi-commit splits — pick files by index (`1 3 5`) instead of typing full paths
- `undo` option at both push confirmation prompts, removing the last commit (pending or made this run) and keeping its changes staged
- `amend` option at both push confirmation prompts, letting you fix the last commit's message (with the folder tag automatically recomputed) without touching its staged changes
- `skip` option at the commit message prompt, letting you bail out of a specific round in a multi-commit split without committing anything for it
- `--status` flag for a quick, non-mutating check of current branch, unpushed commits, and uncommitted changes already in the repo

### Fixed
- Uncommitted file lists in `--status` output no longer print all on one line — each file now shows on its own line

## v1.0.0 — First stable release

Pack Commit's first stable release. Syncs your modpack's config/kubejs/etc. folders into a GitHub repo and walks you through committing and pushing, with the following features:

### Core workflow
- Syncs configured folders (via `rsync -a --delete`) into your repo before every run
- Detects when nothing changed and lets you close, recheck (`r`), or view help — without needing to relaunch the script
- Shows exactly what changed (`git status --short`) before doing anything
- Split changes into any number of separate commits, each with its own file/folder selection and message
- Automatically tags each commit message (and log entry) with every synced folder actually touched in that specific commit — e.g. `[config, kubejs] message`

### Safety
- Verifies your repo path exists and is an actual git repository before doing anything
- Verifies every configured sync source path exists
- Detects an interrupted rebase on startup and stops with clear recovery instructions instead of continuing into a broken state
- Unstages any leftover staged files before starting a commit split, so each round only contains what you actually specify
- Only counts a commit as made if `git commit` actually succeeds — no more false positives in the summary
- Runs `git pull --rebase` automatically before pushing, with clear conflict-resolution steps if it fails
- Asks for confirmation before the final push

### Convenience
- `--dry-run` flag to preview syncs and changes without committing or pushing anything
- `--stats` flag showing total logged commits, commits this month, and first/most recent logged entry
- Detects commits made in a previous run that were never pushed, shows you what's pending, and offers to push them immediately
- Optional commit message history: type `history` at the message prompt to reuse one of your last 5 messages
- `-h` / `--help` flag, plus in-prompt `help` recognition at every interactive prompt
- Displays your current branch at startup and before pushing, as a sanity check
- Logs every push to a local `logs/pack-commit.log`, gitignored by default
