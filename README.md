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
3. Edit `config.fish` with your own paths, pack name, and (optionally) credits.
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
- `--stats` — show a summary of your logged commit history (total logged, this month, first/most recent) and exit

What happens when you run it:
- If a previous run was interrupted mid-rebase, it detects that immediately and tells you to resolve it (`git rebase --continue` or `git rebase --abort`) before doing anything else.
- It shows your current branch as a quick sanity check before anything happens.
- If you have commits sitting locally from a previous run that never got pushed (e.g. you answered "n" to the push prompt last time), it shows you exactly what's pending — commit summaries and which files changed — and offers to push them right away.
- It then syncs your configured folders and shows you what changed (`git status --short`).
- If nothing changed, it tells you and exits.
- If something changed, it asks how many commits you want to split the changes into (type `help` at this prompt for a quick reminder of how that works). Any files left staged from outside this run are unstaged first, so each commit round only ever contains what you actually specify for it.
  - For a single commit (the default), it stages everything and asks for one message.
  - For multiple commits, it asks for specific file/folder paths for each commit round — press Enter with no paths to sweep up everything remaining into that commit.
  - At the commit message prompt, type `history` to see your last 5 logged messages and either reuse one by number or type a new one.
  - A round only counts toward the final push if `git commit` actually created a commit — if nothing was staged for that round, it's skipped rather than falsely counted.
- Before pushing, it shows the branch you're pushing to and asks for confirmation. Answering "n" leaves your commits saved locally; next time you run the script, it'll detect and offer to push them.
- Pushes once at the end (auto-rebasing on top of any remote changes first) and shows a summary of what was actually pushed.

## Logs

Every successful push (including pending ones pushed on a later run) is appended to `logs/pack-commit.log`, next to the script, with a timestamp and the pack name. This folder is gitignored by default so it stays local to your machine.

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
- Before pushing, the script runs `git pull --rebase` automatically to avoid rejected pushes from diverged branches. If a real conflict comes up, it stops and tells you exactly what to run to resolve it manually.
