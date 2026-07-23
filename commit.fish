#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set config_file "$script_dir/config.fish"

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
echo "========================================="
echo ""
set_color normal

for folder in $SYNC_FOLDERS
    set src (echo $folder | cut -d ':' -f1)
    set dest (echo $folder | cut -d ':' -f2)
    rsync -a --delete "$src/" "$dest/"
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

echo "How many separate commits do you want to split these changes into? (default 1)"
read -P "> " commit_count

if test -z "$commit_count"
    set commit_count 1
end

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
git log --oneline -$commit_count

echo ""
echo "Press Enter to close."
read
