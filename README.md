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

- If nothing changed since your last commit, it tells you and exits.
- If something changed, it shows you the file list (`git status --short`) and asks how many commits you want to split the changes into.
- For a single commit (the default), it stages everything and asks for one message.
- For multiple commits, it asks for specific file/folder paths for each commit round — press Enter with no paths to sweep up everything remaining into that commit.
- Pushes once at the end and shows a summary of what was pushed.

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
