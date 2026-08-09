# Pack Commit

A small fish shell script for Minecraft modpack developers who keep their `config`, `kubejs`, or other folders mirrored into a GitHub repo. It syncs your live/dev folders into the repo, shows you what changed, and walks you through committing (optionally splitting changes into multiple commits with their own messages) before pushing.

## Requirements

- [fish shell](https://fishshell.com/)
- `git` and `rsync` installed
- A local clone of your modpack's GitHub repo

## Setup

1. Clone or download this tool.
2. Copy `config.example.fish` to `config.fish`:
   ```fish
   cp config.example.fish config.fish
   ```
3. Edit `config.fish` with your own paths, pack name, and (optionally) credits and a version string. Each `SYNC_FOLDERS` entry needs a `source:destination` format — the script checks this at startup and will tell you if an entry is malformed.
4. Make the script executable:
   ```fish
   chmod +x commit.fish
   ```
5. (Optional) Move both files somewhere permanent, like `~/.local/bin/pack-commit/`, and add that folder to your `PATH` so you can run it from anywhere.

## Usage

Run it:
```fish
./commit.fish
```

Options:
- `-h`, `--help` — show usage info and exit
- `--dry-run` — show what would be synced and what changed, without committing or pushing anything
- `--info` — show current branch, unpushed commits, and log stats.

What happens when you run it:
- If a previous run was interrupted mid-rebase, it detects that immediately and tells you to resolve it (`git rebase --continue` or `git rebase --abort`) before doing anything else. Similarly, if a previous run got interrupted mid-stash (rare, but possible if the terminal closed at the wrong moment), it detects the leftover stash and tells you exactly how to recover or discard it.
- It shows your current branch as a quick sanity check before anything happens, along with a "Last synced" line if a previous push has been logged (relative time plus the exact timestamp), and displays any active scheduled tasks.
- If you have commits sitting locally from a previous run that never got pushed (e.g. you answered "n" to the push prompt last time), it shows you exactly what's pending — commit summaries and which files changed — and lets you:
  - push them now
  - skip (they'll show up again next run)
  - `undo` the last one (kept staged, not lost) if you want to redo it
  - `amend` the last one's message if only the wording was wrong
  - `undo N` or `amend N` (e.g., `amend 1`) to target any specific older commit in the current stack, even from previous runs.
  - `undo all` to remove every pending commit made during the current session at once.
  - `schedule HH:MM` to defer pushes to a specific time. This runs detached in the background, allowing scheduled pushes to continue safely even after the terminal is closed.
- It then syncs your configured folders and shows you what changed (`git status --short`).
- If nothing changed, it doesn't just exit — it offers to check again right there: type `r` to re-sync and check for changes, `help` for a quick reminder, or press Enter to close. Handy if you're editing files with the script's terminal left open, so you don't need to relaunch it from scratch every time.
- If something changed, it asks how many commits you want to split the changes into (type `help` at this prompt for a quick reminder, or `r` to re-sync your folders and re-check for changes — handy if source files are still being written when you reach this point, e.g. a game or launcher still saving on exit). Invalid input here gets a clear rejection message rather than being silently accepted, and if only a single file has changed, you're restricted to 1 commit (still free to type `r`/`help`) since splitting one file across multiple commits doesn't make sense. Any files left staged from outside this run are unstaged first, so each commit round only ever contains what you actually specify for it.
  - For a single commit (the default), it stages everything and asks for one message.
  - For multiple commits, instead of typing file paths, you get a **numbered list** of remaining changed files (aligned consistently even past 9 entries) — just type the numbers you want (e.g. `1 3`), space-separated. Press Enter with no numbers to sweep up everything remaining into that commit. Invalid input re-prompts you instead of silently defaulting.
  - At the commit message prompt: type `history` to reuse one of your last 5 logged messages (which now features smarter history-reuse tag stripping based on your configured `SYNC_FOLDERS`), or `skip` to bail out of that specific round entirely without committing anything for it.
  - A round only counts toward the final push if `git commit` actually created a commit — if nothing was staged for that round, it's skipped rather than falsely counted.
- Before pushing, it shows the branch you're pushing to and asks for confirmation — the exact same `undo`/`amend`, `undo N`/`amend N`, `undo all`, and `schedule HH:MM` options are available here too for commits made during this run. Pending-commit actions will no longer reprint the entire commit list after every action or invalid input.
- Pushes once at the end (auto-rebasing on top of any remote changes first) and shows a summary of what was actually pushed, plus a colorized aggregate diffstat (green insertions, red deletions; total files/insertions/deletions across every commit made this run — accurate even if you used `undo`, `amend`, or `skip` along the way) and how long the whole run took. Each individual commit's own summary is colorized the same way.
- After a successful or skipped push, the script now returns directly to the sync-check step instead of exiting.

## Logs

Every successful push (including pending ones pushed on a later run) is appended to `logs/pack-commit.log`, next to the script, with a timestamp, pack name, and the folder tag for that commit. This folder is gitignored by default so it stays local to your machine.

## Desktop shortcut (Linux/KDE)

If you'd rather double-click an icon than open a terminal manually, create a `.desktop` file:

```ini
[Desktop Entry]
Type=Application
Name=Pack Commit
Exec=konsole -e fish -c "~/.local/bin/pack-commit/commit.fish"
Icon=utilities-terminal
Terminal=false
```

Swap `konsole` for your terminal of choice if you're not on KDE. You may need to right-click the file → Properties → allow execution the first time you use it.

## Notes

- `config.fish` is gitignored so your personal paths and Discord link never end up committed if you fork/publish this tool.
- The sync step uses `rsync -a --delete`, which mirrors folders exactly — including removing files from the destination that no longer exist in the source. This is intentional (so deleted configs actually get removed from the repo), but be aware of it.
- Before pushing, the script only runs `git pull --rebase` if the remote actually has new commits — no wasted work if you're already up to date. When a rebase genuinely is needed and you have uncommitted changes sitting around (e.g. from a `skip`ped commit round), they're automatically stashed first and restored afterward, with the stashed/restored files shown for visibility. If a real conflict comes up during the rebase, it stops and tells you exactly what to run to resolve it manually.
- `undo N` and `amend N` allow you to target older commits. The script will automatically stash and restore any uncommitted changes when modifying older commits.
- `undo` and `amend` operations targeting the latest commit now use native Git operations instead of rebasing, which safely handles staged changes. 
- Scheduled pushes preserve every individual commit and message precisely instead of squashing them.
- The script uses consistent status icons (`✓` success, `✗` error, `!` warning, `→` info) to clearly display the state of operations throughout the process.
