#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set config_file "$script_dir/config.fish"

set dry_run 0

for arg in $argv
    switch $arg
        case "-h" "--help"
            echo "Usage: commit.fish [options]"
            echo ""
            echo "Syncs configured folders into your repo, then walks you through"
            echo "committing (optionally split across multiple commits) and pushing."
            echo ""
            echo "Options:"
            echo "  -h, --help      Show this help message and exit"
            echo "  --dry-run       Show what would be synced and what changed, without"
            echo "                  committing or pushing anything"
            echo ""
            echo "Config is read from config.fish next to this script."
            echo "See config.example.fish for the expected format."
            exit 0
        case "--dry-run"
            set dry_run 1
    end
end

if not test -f "$config_file"
    set_color red
    echo "config.fish not found next to commit.fish."
    echo "Copy config.example.fish to config.fish and edit it first."
    set_color normal
    exit 1
end

source "$config_file"

if not set -q PACK_NAME; or not set -q REPO_PATH; or not set -q SYNC_FOLDERS
    set_color red
    echo "config.fish is missing required variables (PACK_NAME, REPO_PATH, SYNC_FOLDERS)."
    echo "Check config.example.fish for the expected format."
    set_color normal
    exit 1
end

# Pre-flight checks
if not test -d "$REPO_PATH"
    set_color red
    echo "REPO_PATH does not exist: $REPO_PATH"
    set_color normal
    exit 1
end

if not test -d "$REPO_PATH/.git"
    set_color red
    echo "REPO_PATH is not a git repository: $REPO_PATH"
    set_color normal
    exit 1
end

set missing_sources 0
for folder in $SYNC_FOLDERS
    set src (echo $folder | cut -d ':' -f1)
    if not test -d "$src"
        set_color red
        echo "Sync source does not exist: $src"
        set_color normal
        set missing_sources 1
    end
end

if test $missing_sources -eq 1
    echo "Fix the paths in config.fish and try again."
    exit 1
end

set_color cyan
echo ""
echo "========================================="
echo "   $PACK_NAME — GitHub Commit Script"
echo "   Syncs and commits pack changes"
if set -q AUTHOR_NAME
    echo "   Made by $AUTHOR_NAME"
end
if set -q DISCORD_LINK
    echo "   Discord: $DISCORD_LINK"
end
if test $dry_run -eq 1
    echo "   [DRY RUN — nothing will be committed or pushed]"
end
echo "========================================="
echo ""
set_color normal

for folder in $SYNC_FOLDERS
    set src (echo $folder | cut -d ':' -f1)
    set dest (echo $folder | cut -d ':' -f2)
    if test $dry_run -eq 1
        echo "Would sync: $src -> $dest"
        rsync -a --delete --dry-run "$src/" "$dest/"
    else
        rsync -a --delete "$src/" "$dest/"
    end
end

cd "$REPO_PATH"

set changes (git status --short)

if test -z "$changes"
    set_color yellow
    echo "No changes detected since last commit. Nothing to do."
    set_color normal
    echo ""
    echo "Press Enter to close."
    read
    exit 0
end

echo ""
set_color yellow
echo "Files changed since last commit:"
set_color normal
git status --short
echo ""

if test $dry_run -eq 1
    set_color cyan
    echo "Dry run complete. No commits or pushes were made."
    set_color normal
    echo ""
    echo "Press Enter to close."
    read
    exit 0
end

echo "How many separate commits do you want to split these changes into? (default 1)"
read -P "> " commit_count

if test -z "$commit_count"
    set commit_count 1
end

set log_dir "$script_dir/logs"
mkdir -p "$log_dir"
set log_file "$log_dir/pack-commit.log"
set run_timestamp (date "+%Y-%m-%d %H:%M:%S")
set committed_messages

for i in (seq 1 $commit_count)
    echo ""
    set_color cyan
    echo "--- Commit $i of $commit_count ---"
    set_color normal

    if test $commit_count -gt 1
        echo "Enter file(s)/folder(s) for this commit, or press Enter to add everything else remaining:"
        read -P "> " commit_paths_raw
    else
        set commit_paths_raw ""
    end

    if test -z "$commit_paths_raw"
        set commit_paths "-A"
    else
        set commit_paths (string split " " -- $commit_paths_raw)
    end

    echo "Enter commit message for commit $i:"
    read -P "> " commit_msg

    if test -z "$commit_msg"
        echo "No message entered, skipping this commit."
        continue
    end

    git add $commit_paths
    git commit -m "$commit_msg"
    set -a committed_messages "$commit_msg"
end

if test (count $committed_messages) -eq 0
    set_color yellow
    echo ""
    echo "No commits were made. Nothing to push."
    set_color normal
    echo ""
    echo "Press Enter to close."
    read
    exit 0
end

echo ""
set_color yellow
echo "About to push (count $committed_messages) commit(s) to origin. Continue? [Y/n]"
set_color normal
read -P "> " push_confirm

if test "$push_confirm" = "n"; or test "$push_confirm" = "N"
    echo "Push skipped. Your commits are saved locally — run git push manually when ready."
    echo ""
    echo "Press Enter to close."
    read
    exit 0
end

set_color yellow
echo ""
echo "Pulling latest changes first..."
set_color normal
git pull --rebase

if test $status -ne 0
    set_color red
    echo ""
    echo "git pull --rebase failed, likely due to a conflict."
    echo "Resolve it manually (git status will show you what's conflicted), then run:"
    echo "  git rebase --continue"
    echo "  git push"
    set_color normal
    echo ""
    echo "Press Enter to close."
    read
    exit 1
end

set_color yellow
echo ""
echo "Pushing to GitHub..."
set_color normal
git push

echo ""
set_color green
echo "Done! Commits pushed this run:"
set_color normal
git log --oneline -(count $committed_messages)

for msg in $committed_messages
    echo "[$run_timestamp] $msg" >> "$log_file"
end

echo ""
echo "Press Enter to close."
read
