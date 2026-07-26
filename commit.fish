#!/usr/bin/env fish

set script_dir (dirname (status --current-filename))
set config_file "$script_dir/config.fish"

set dry_run 0
set log_dir "$script_dir/logs"
set log_file "$log_dir/pack-commit.log"
set run_timestamp (date "+%Y-%m-%d %H:%M:%S")

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
            echo "  --stats         Show a summary of logged commits and exit"
            echo "  --status        Show current branch, unpushed commits, and any"
            echo "                  uncommitted changes already in the repo, then exit"
            echo ""
            echo "Config is read from config.fish next to this script."
            echo "See config.example.fish for the expected format."
            exit 0
        case "--dry-run"
            set dry_run 1
        case "--stats"
            if not test -f "$log_file"
                echo "No log file found yet at $log_file"
                exit 0
            end

            set total_lines (count (cat "$log_file"))
            set current_month (date "+%Y-%m")
            set this_month_lines (grep -c "^\[$current_month" "$log_file" 2>/dev/null; or echo 0)
            set first_line (head -n 1 "$log_file")
            set last_line (tail -n 1 "$log_file")

            set_color cyan
            echo "=== $PACK_NAME — Commit Log Stats ==="
            set_color normal
            echo "Total logged commits: $total_lines"
            echo "Commits this month:   $this_month_lines"
            echo ""
            echo "First logged commit:"
            echo "  $first_line"
            echo "Most recent commit:"
            echo "  $last_line"
            exit 0
        case "--status"
            if not test -d "$REPO_PATH"
                echo "REPO_PATH does not exist: $REPO_PATH"
                exit 1
            end
            if not test -d "$REPO_PATH/.git"
                echo "REPO_PATH is not a git repository: $REPO_PATH"
                exit 1
            end

            cd "$REPO_PATH"

            set_color cyan
            echo "=== $PACK_NAME — Status ==="
            set_color normal
            echo "Current branch: "(git rev-parse --abbrev-ref HEAD)

            set status_pending (git rev-list --count '@{u}..HEAD' 2>/dev/null)
            if test -n "$status_pending"; and test "$status_pending" -gt 0
                set_color yellow
                echo "$status_pending unpushed commit(s):"
                set_color normal
                git log --oneline '@{u}..HEAD'
            else
                echo "No unpushed commits."
            end

            echo ""
            set repo_changes (git status --short)
            if test -n "$repo_changes"
                set_color yellow
                echo "Uncommitted changes already in the repo folder:"
                set_color normal
                for line in $repo_changes
                    echo "$line"
                end
                echo ""
                echo "Note: this doesn't check for new edits still sitting in your"
                echo "sync source folders that haven't been synced in yet — run the"
                echo "script normally (no flags) for that."
            else
                echo "No uncommitted changes currently in the repo folder."
                echo ""
                echo "Note: this doesn't check for new edits still sitting in your"
                echo "sync source folders that haven't been synced in yet — run the"
                echo "script normally (no flags) for that."
            end
            exit 0
    end
end

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

if test -d "$REPO_PATH/.git/rebase-merge"; or test -d "$REPO_PATH/.git/rebase-apply"
    set_color red
    echo "A rebase is already in progress in $REPO_PATH."
    echo "Resolve it first: go into the repo and run either"
    echo "  git rebase --continue"
    echo "or, to back out entirely:"
    echo "  git rebase --abort"
    set_color normal
    echo ""
    echo "Press Enter to close."
    read
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

function get_last_sync_line
    if not test -f "$log_file"
        return
    end
    set last_line (tail -n 1 "$log_file")
    set matches (string match -r '^\[([^\]]+)\]' -- "$last_line")
    if test (count $matches) -lt 2
        return
    end
    set log_ts $matches[2]

    set log_epoch (date -d "$log_ts" +%s 2>/dev/null)
    if test -z "$log_epoch"
        return
    end
    set now_epoch (date +%s)
    set diff (math $now_epoch - $log_epoch)

    if test $diff -lt 60
        set rel "just now"
    else if test $diff -lt 3600
        set mins (math -s0 "$diff / 60")
        set rel "$mins min ago"
    else if test $diff -lt 86400
        set hours (math -s0 "$diff / 3600")
        set rel "$hours hour(s) ago"
    else
        set days (math -s0 "$diff / 86400")
        set rel "$days day(s) ago"
    end

    echo "   Last synced: $rel ($log_ts)"
end

function print_banner
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
    if set -q TOOL_VERSION
        echo "   Version: $TOOL_VERSION"
    end
    get_last_sync_line
    if test $dry_run -eq 1
        echo "   [DRY RUN — nothing will be committed or pushed]"
    end
    echo "========================================="
    echo ""
    set_color normal
end

function print_branch
    set_color yellow
    echo "Current branch: $current_branch"
    set_color normal
    echo ""
end

function get_head_folder_tag
    set files_in_commit (git diff-tree --no-commit-id --name-only -r HEAD)
    set touched
    for folder in $SYNC_FOLDERS
        set dest (echo $folder | cut -d ':' -f2)
        set folder_name (basename "$dest")
        for f in $files_in_commit
            if string match -q "$folder_name/*" -- "$f"
                if not contains "$folder_name" $touched
                    set -a touched "$folder_name"
                end
                break
            end
        end
    end
    if test (count $touched) -gt 0
        set tag "[" (string join ", " $touched) "]"
        string join "" $tag
    end
end

print_banner

cd "$REPO_PATH"

set current_branch (git rev-parse --abbrev-ref HEAD)
print_branch

set pending_count (git rev-list --count '@{u}..HEAD' 2>/dev/null)

if test -n "$pending_count"; and test "$pending_count" -gt 0
    while true
        set pending_count (git rev-list --count '@{u}..HEAD' 2>/dev/null)

        if test -z "$pending_count"; or test "$pending_count" -eq 0
            set_color yellow
            echo "No pending commits left to push."
            set_color normal
            break
        end

        set_color yellow
        echo "You have $pending_count commit(s) not yet pushed from a previous run:"
        set_color normal

        git log --oneline --stat '@{u}..HEAD'

        echo ""
        echo "Push these now? [Y/n], or type 'undo' to remove the last local commit, 'amend' to fix its message:"
        read -P "> " pending_push_confirm

        if test "$pending_push_confirm" = "undo"
            git reset --soft HEAD~1
            set_color yellow
            echo "Removed the last local commit (its changes are kept, now staged)."
            set_color normal
            continue
        end

        if test "$pending_push_confirm" = "amend"
            echo "Enter the corrected commit message:"
            read -P "> " new_msg

            if test -z "$new_msg"
                echo "No message entered, amend cancelled."
                continue
            end

            set folder_tag (get_head_folder_tag)
            if test -n "$folder_tag"
                set new_msg "$folder_tag $new_msg"
            end

            git commit --amend -m "$new_msg"
            set_color green
            echo "Commit message updated."
            set_color normal
            continue
        end

        if not test "$pending_push_confirm" = "n"; and not test "$pending_push_confirm" = "N"
            set_color yellow
            echo "Pulling latest changes first..."
            set_color normal
            git pull --rebase

            if test $status -ne 0
                set_color red
                echo "git pull --rebase failed, likely due to a conflict."
                echo "Resolve it manually, then run 'git rebase --continue' and 'git push'."
                set_color normal
                echo ""
                echo "Press Enter to close."
                read
                exit 1
            end

            set pending_msgs (git log --format="%s" '@{u}..HEAD')

            git push
            set_color green
            echo "Pending commits pushed."
            set_color normal

            mkdir -p "$log_dir"
            for msg in $pending_msgs
                echo "[$run_timestamp] [$PACK_NAME] [PENDING PUSH] $msg" >> "$log_file"
            end
        else
            echo "Skipped. They'll show up again next time you run this script."
        end
        break
    end
    echo ""
end

set no_changes_choice ""
set first_check 1
while true
    if test $first_check -eq 0
        clear
        print_banner
        print_branch
    end
    set first_check 0

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

    set changes (git status --short)

    if test -n "$changes"
        break
    end

    if test $dry_run -eq 1
        set_color yellow
        echo "No changes detected. (dry run, nothing to sync anyway)"
        set_color normal
        echo ""
        echo "Press Enter to close."
        read
        exit 0
    end

    set_color yellow
    echo "No changes detected since last commit."
    set_color normal
    echo "Press Enter to close, type 'r' to check again, or 'help' for usage info:"
    read -P "> " no_changes_choice

    if test "$no_changes_choice" = "help"; or test "$no_changes_choice" = "--help"
        echo ""
        echo "Usage:"
        echo "  'r'     — re-sync your folders and check for changes again"
        echo "  Enter   — close the script"
        echo ""
        echo "Press Enter to continue."
        read
    else if test -z "$no_changes_choice"
        echo ""
        echo "Press Enter to close."
        read
        exit 0
    end
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

set valid_input 0
set commit_prompt_first 1
while test $valid_input -eq 0
    if test $commit_prompt_first -eq 0
        clear
        print_banner
        print_branch
        echo ""
        set_color yellow
        echo "Files changed since last commit:"
        set_color normal
        git status --short
        echo ""
    end
    set commit_prompt_first 0

    echo "How many separate commits do you want to split these changes into? (default 1, type 'help' for usage info, 'r' to re-sync and check for more changes)"
    read -P "> " commit_count

    if test "$commit_count" = "r"
        echo ""
        set_color cyan
        echo "Re-syncing..."
        set_color normal
        for folder in $SYNC_FOLDERS
            set src (echo $folder | cut -d ':' -f1)
            set dest (echo $folder | cut -d ':' -f2)
            rsync -a --delete "$src/" "$dest/"
        end
    else if test "$commit_count" = "help"; or test "$commit_count" = "--help"
        echo ""
        echo "Usage:"
        echo "  Enter a number to split your changes into that many commits, each"
        echo "  with its own file selection and message."
        echo "  Press Enter with nothing typed to default to a single commit"
        echo "  containing everything that changed."
        echo "  At the commit message prompt, type 'history' to see your last"
        echo "  5 commit messages and optionally reuse one, or 'skip' to skip"
        echo "  that round entirely."
        echo ""
        echo "Press Enter to continue."
        read
    else
        if test -z "$commit_count"
            set commit_count 1
        end
        set valid_input 1
    end
end

set start_commit (git rev-parse HEAD)
git reset > /dev/null

set committed_messages

for i in (seq 1 $commit_count)
    echo ""
    set_color cyan
    echo "--- Commit $i of $commit_count ---"
    set_color normal

    if test $commit_count -gt 1
        set remaining_status (git status --short)
        if test -z "$remaining_status"
            set commit_paths "-A"
        else
            set remaining_paths
            set idx 1
            echo "Remaining changed files:"
            for line in $remaining_status
                set fpath (string sub -s 4 -- $line)
                set -a remaining_paths "$fpath"
                echo "  $idx) $line"
                set idx (math $idx + 1)
            end
            echo "Enter number(s) separated by spaces for this commit, or press Enter to add everything else remaining:"
            read -P "> " picker_raw

            if test -z "$picker_raw"
                set commit_paths "-A"
            else
                set commit_paths
                for n in (string split " " -- $picker_raw)
                    if string match -qr '^[0-9]+$' -- "$n"
                        set chosen $remaining_paths[$n]
                        if test -n "$chosen"
                            set -a commit_paths "$chosen"
                        else
                            echo "Invalid number: $n, skipping."
                        end
                    else
                        echo "Invalid input: $n, skipping."
                    end
                end
                if test (count $commit_paths) -eq 0
                    echo "No valid selections, defaulting to everything else remaining."
                    set commit_paths "-A"
                end
            end
        end
    else
        set commit_paths "-A"
    end

    set commit_msg ""
    set skip_round 0
    while test -z "$commit_msg"
        echo "Enter commit message for commit $i (or type 'history' to reuse a recent one, 'skip' to skip this round):"
        read -P "> " commit_msg_raw

        if test "$commit_msg_raw" = "skip"
            set skip_round 1
            break
        end

        if test "$commit_msg_raw" = "history"
            if test -f "$log_file"
                set_color cyan
                echo "Last 5 commit messages:"
                set_color normal
                set recent_msgs (tail -n 5 "$log_file")
                set idx 1
                for line in $recent_msgs
                    echo "  $idx) $line"
                    set idx (math $idx + 1)
                end
                echo "Type a number to reuse one, or type a new message:"
                read -P "> " history_choice

                if string match -qr '^[0-9]+$' -- "$history_choice"
                    set chosen_line $recent_msgs[$history_choice]
                    if test -n "$chosen_line"
                        set commit_msg (string replace -r '^\[.*?\]\s*\[.*?\]\s*(\[PENDING PUSH\]\s*)?' '' -- "$chosen_line")
                    else
                        echo "Invalid number, try again."
                    end
                else
                    set commit_msg "$history_choice"
                end
            else
                echo "No log file yet, nothing to reuse."
            end
        else
            set commit_msg "$commit_msg_raw"
        end
    end

    if test $skip_round -eq 1
        set_color yellow
        echo "Skipped commit $i."
        set_color normal
        continue
    end

    git add $commit_paths

    set staged_files (git diff --cached --name-only)
    set touched_folders
    for folder in $SYNC_FOLDERS
        set dest (echo $folder | cut -d ':' -f2)
        set folder_name (basename "$dest")
        for f in $staged_files
            if string match -q "$folder_name/*" -- "$f"
                if not contains "$folder_name" $touched_folders
                    set -a touched_folders "$folder_name"
                end
                break
            end
        end
    end

    if test (count $touched_folders) -gt 0
        set folder_tag "[" (string join ", " $touched_folders) "]"
        set folder_tag (string join "" $folder_tag)
        set commit_msg "$folder_tag $commit_msg"
    end

    if git commit -m "$commit_msg"
        set -a committed_messages "$commit_msg"
    else
        set_color yellow
        echo "Nothing was actually committed for this round (no staged changes matched), skipping."
        set_color normal
    end
end

set commit_num_made (count $committed_messages)

if test $commit_num_made -eq 0
    set_color yellow
    echo ""
    echo "No commits were made. Nothing to push."
    set_color normal
    echo ""
    echo "Press Enter to close."
    read
    exit 0
end

while true
    if test $commit_num_made -eq 0
        set_color yellow
        echo ""
        echo "No commits left to push."
        set_color normal
        echo ""
        echo "Press Enter to close."
        read
        exit 0
    end

    echo ""
    set_color yellow
    echo "About to push $commit_num_made commit(s) to branch '$current_branch'. Continue? [Y/n], or type 'undo'/'amend':"
    set_color normal
    read -P "> " push_confirm

    if test "$push_confirm" = "undo"
        git reset --soft HEAD~1
        set -e committed_messages[-1]
        set commit_num_made (count $committed_messages)
        set_color yellow
        echo "Removed the last commit made this run (its changes are kept, now staged)."
        set_color normal
        continue
    end

    if test "$push_confirm" = "amend"
        echo "Enter the corrected commit message:"
        read -P "> " new_msg

        if test -z "$new_msg"
            echo "No message entered, amend cancelled."
            continue
        end

        set folder_tag (get_head_folder_tag)
        if test -n "$folder_tag"
            set new_msg "$folder_tag $new_msg"
        end

        git commit --amend -m "$new_msg"
        set committed_messages[-1] "$new_msg"
        set_color green
        echo "Commit message updated."
        set_color normal
        continue
    end

    break
end

if test "$push_confirm" = "n"; or test "$push_confirm" = "N"
    echo "Push skipped. Your commits are saved locally — next time you run this"
    echo "script, it'll offer to push them for you."
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
git log --oneline -$commit_num_made

echo ""
set_color cyan
git diff --shortstat $start_commit HEAD
set_color normal

mkdir -p "$log_dir"
for msg in $committed_messages
    echo "[$run_timestamp] [$PACK_NAME] $msg" >> "$log_file"
end

echo ""
echo "Press Enter to close."
read
