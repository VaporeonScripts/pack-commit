# Changelog

## v1.8.0 — Scheduling reliability, safer conflict handling, and quality-of-life fixes

### Added
* Added an 'exit' option at the "How many commits" prompt to close the script without committing any changes

### Fixed
* Multi-line commit descriptions no longer show an extra blank line between each typed line — they now display tight together, matching GitHub's commit UI behavior
* Fixed a race condition where two scheduled background pushes could both believe they'd acquired the lock simultaneously, causing them to collide and push at the same time
* Scheduled pushes now give up cleanly after 10 minutes if they can't safely acquire the lock, instead of waiting forever as an orphaned background process
* The "waiting to be idle" window for scheduled pushes now covers every interactive prompt in the script, not just the "No changes detected" screen — significantly reducing how long a scheduled push may need to wait
* The "No changes detected" screen now automatically refreshes once a scheduled push finishes, clearing the stale "Scheduled for HH:MM" label without requiring manual input
* Fixed the commit message prompt flooding the terminal with repeated prompts when submitted empty — it now warns, pauses, and clears just that failed attempt before re-prompting

### Changed
* Pull/rebase now automatically retries up to 3 times on failure (aborting cleanly between attempts), and resolves any conflicting lines in favor of local changes instead of stopping and requiring manual resolution

## v1.7.0 — Range selection, repo info, and picker/prompt polish

### Added
* File picker now supports numeric ranges (e.g. `1-5`) alongside individual numbers, and can be mixed (`1-5 9`)
* Banner now shows the repo's owner/name and total commit count

### Fixed
* Diffstat bars for large file changes no longer stretch across the whole terminal, while file names and line counts stay untouched
* Multiple invalid entries in the file picker are now shown as a single consolidated message instead of one line per bad entry, and no longer crash on dash-prefixed input (e.g. `-224`)
* Invalid commit numbers for `undo N`/`amend N` at both the pending-commit and fresh-push confirmation prompts now properly clear and redraw the screen instead of leaving a stale or incomplete display
* Unrecognized input at the pending-commit prompt no longer produces duplicated or corrupted screen output when the commit recap is long

## v1.6.0 — Scheduled push logging fix and safer push confirmation

### Added
* Warning when committing files that don't match any folder defined in `SYNC_FOLDERS`, with the option to cancel before committing
* Optional multi-line commit descriptions (like GitHub's commit UI) — press Enter to skip, or type lines and finish with a blank line
* File picker now shows even when committing everything as a single commit, allowing you to exclude specific files without needing to split into multiple commits

### Fixed
* Scheduled push log entries now write the actual timestamp instead of the literal unexpanded date command
* Scheduled push commands now correctly expand variables and command substitutions in the background shell
* Push confirmation prompts no longer treat unrecognized input as a yes — only `y`, `Y`, or empty Enter confirm
* Fixed the "About to push N commit(s)" prompt breaking out to the sync screen on invalid input instead of re-prompting
* Fixed the same unrecognized-input issue in the pending-commits-from-previous-run prompt
* Invalid input at either push-confirmation prompt now clears only that failed attempt in place, instead of duplicating prompts or wiping the whole screen
* Fixed misaligned status letters in the changed-files list — staged and unstaged changes of the same type now line up in the same column, colored to distinguish them
* File picker no longer shows for single-file changes, since there's nothing meaningful to pick

### Changed
* Removed `--stats` and `--status` flags, merged into `--info` (already showed the combined view)

## v1.5.0 — Scheduled pushes, advanced commit management, and safer history editing

### Added

* Scheduled pushes with `schedule HH:MM`, allowing pushes to be deferred to a specific time
* Background execution for scheduled pushes, allowing them to continue after the terminal is closed
* Scheduled task visibility in the banner and through `--status`/`--info`
* `undo N` / `amend N` support for targeting any commit in the current stack, including commits from previous runs
* `undo all` for removing every commit made during the current session at once
* Automatic stashing and restoration of uncommitted changes when modifying older commits
* Smarter history-reuse tag stripping based on the configured `SYNC_FOLDERS`
* Consistent status icons across the script (`✓` success, `✗` error, `!` warning, `→` info)

### Changed

* After a successful or skipped push, the script now returns to the sync-check step instead of exiting
* Scheduled pushes preserve every individual commit and message instead of squashing them
* Latest-commit `undo`/`amend` operations now use native Git operations instead of rebasing, allowing them to safely handle staged changes
* `TOOL_VERSION` bumped to 1.5.0

### Fixed

* Pending-commit actions no longer reprint the entire commit list after every action or invalid input
* Warning icon changed from `⚠` to `!` for more reliable terminal rendering
* Replaced the original foreground polling scheduler with detached background execution for more reliable scheduled pushes
* Commit hash matching now works reliably regardless of the hash length shown by Git

### Internal

* Added dedicated handling for older-commit history editing, including automatic stash protection and dynamic commit targeting
* Improved separation between normal commit handling, scheduled pushes, and history-rewriting operations


## v1.4.0 — Colorized output, safer pulls, and cleanup

### Added
- Colorized `git diff --shortstat` output (green insertions, red deletions) in both the aggregate run summary and every individual commit's own summary line
- `--version` flag
- `--info` flag, combining `--status` and `--stats` into a single view
- Detection of a leftover stash from a previous interrupted run, with clear recovery instructions
- Visibility into exactly which files get temporarily stashed and restored around a rebase

### Fixed
- Pushes no longer fail when a `skip`ped commit round left uncommitted changes in the working directory — `pull --rebase` now only runs when the remote actually has new commits, and safely stashes/restores uncommitted changes around it when a rebase is genuinely needed
- Fixed a function-ordering bug that could have caused a crash (instead of showing the intended message) if the mid-rebase or orphaned-stash checks were ever triggered

### Internal
- Refactored repeated logic into shared functions (sync, output coloring, folder tagging, pause prompts, safe pull/rebase) — no behavior change, just less duplicated code to maintain

## v1.3.0 — Safer prompts and a run summary

### Added
- Validation for `SYNC_FOLDERS` entries in `config.fish`, catching a missing `:` separator before attempting to use malformed paths
- A restriction preventing commit counts greater than 1 when only a single file has changed, while still allowing `r`/`help` at that prompt
- Clear rejection messages for invalid input at the "How many commits" prompt, instead of silently defaulting
- A run duration timer, shown at the end alongside the diffstat summary (measures the whole run including time spent on prompts, not just execution time)

### Fixed
- The numbered file picker no longer silently defaults to "everything remaining" on invalid non-blank input — it now re-prompts until you give valid input or explicitly press Enter for the default
- The numbered file picker's alignment no longer breaks once entries reach double digits — index numbers pad to a consistent width based on the total file count
- The file picker's retry flow now properly shows error messages before clearing them (previously they were erased instantly, before they could be read), and no longer leaves a duplicate prompt line behind afterward

## v1.2.0 — Re-sync mid-run, sync timestamp, and run summary

### Added
- `r` option at the "How many commits" prompt to re-sync your configured folders and re-check for changes without leaving the script — useful if source files are still being written when you reach that point (e.g. a game/launcher still saving files)
- Optional `TOOL_VERSION` variable in `config.fish`, shown in the banner if set
- "Last synced" line in the banner, showing both relative (`2 hour(s) ago`) and absolute timestamp of the last logged push
- Aggregate diffstat summary at the end of a run (total files/insertions/deletions across every commit made that run, accurate even if `undo`/`amend`/`skip` were used along the way)

### Fixed
- The `help` text at the "How many commits" prompt now pauses for you to read before the next screen clear wipes it

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
