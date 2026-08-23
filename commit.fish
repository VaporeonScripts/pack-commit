#!/usr/bin/env fish

function say_ok
    set_color green
    echo -n "✓ "
    set_color normal
    echo $argv
end

function say_err
    set_color red
    echo -n "✗ "
    set_color normal
    echo $argv
end

function say_warn
    set_color yellow
    echo -n "! "
    set_color normal
    echo $argv
end

function say_info
    set_color cyan
    echo -n "→ "
    set_color normal
    echo $argv
end

set script_dir (dirname (status --current-filename))
set config_path "$script_dir/config.fish"

if not test -f "$config_path"
    say_err "config.fish not found at $config_path"
    say_info "Copy config.example.fish to config.fish and fill in your settings."
    exit 1
end

source "$config_path"

if not set -q PACK_NAME
    set PACK_NAME "My Modpack"
end
if not set -q AUTHOR_NAME
    set AUTHOR_NAME ""
end
if not set -q DISCORD_LINK
    set DISCORD_LINK ""
end
if not set -q TOOL_VERSION
    set TOOL_VERSION "unknown"
end

if not set -q REPO_PATH
    say_err "REPO_PATH is not set in config.fish."
    exit 1
end

if not set -q SYNC_FOLDERS
    say_err "SYNC_FOLDERS is not set in config.fish."
    exit 1
end

set dry_run 0
set script_start_time (date +%s)
set log_dir "$script_dir/logs"
set log_file "$log_dir/pack-commit.log"
set run_timestamp (date "+%Y-%m-%d %H:%M:%S")

function print_scheduled_tasks
    set task_file "$log_dir/scheduled_tasks"
    if test -f "$task_file"
        set active_tasks
        set printed_any 0
        for line in (cat "$task_file")
            set pid (echo $line | cut -d'|' -f1)
            set time (echo $line | cut -d'|' -f2)
            if kill -0 $pid 2>/dev/null
                set -a active_tasks $line
                if test $printed_any -eq 0
                    set_color cyan
                    echo "--- Scheduled Tasks ---"
                    set_color normal
                    set printed_any 1
                end
                say_info "Push scheduled for $time (PID: $pid)"
            end
        end
        if test (count $active_tasks) -gt 0
            printf "%s\n" $active_tasks > "$task_file"
        else
            rm -f "$task_file"
        end
        if test $printed_any -eq 1
            echo ""
        end
    end
end

for arg in $argv
    switch $arg
        case "-h" "--help"
            echo "Usage: commit.fish [options]"
            echo ""
            echo "Options:"
            echo "  -h, --help      Show this help message and exit"
            echo "  --dry-run       Show what would be synced and what changed"
            echo "  --info          Show current branch, unpushed commits, and log stats"
            echo "  --version       Show the tool's version and exit"
            exit 0
        case "--version"
            echo "$PACK_NAME Commit Script — version $TOOL_VERSION"
            exit 0
        case "--dry-run"
            set dry_run 1
        case "--info"
            if not test -d "$REPO_PATH"
                say_err "REPO_PATH does not exist: $REPO_PATH"
                exit 1
            end
            if not test -d "$REPO_PATH/.git"
                say_err "REPO_PATH is not a git repository: $REPO_PATH"
                exit 1
            end
            cd "$REPO_PATH"
            set_color cyan
            echo "=== $PACK_NAME — Info ==="
            set_color normal
            echo "Current branch: "(git rev-parse --abbrev-ref HEAD)
            set info_pending (git rev-list --count '@{u}..HEAD' 2>/dev/null)
            if test -n "$info_pending"; and test "$info_pending" -gt 0
                say_warn "$info_pending unpushed commit(s):"
                git log --oneline '@{u}..HEAD'
            else
                say_ok "No unpushed commits."
            end
            echo ""
            set info_changes (git status --short)
            if test -n "$info_changes"
                say_warn "Uncommitted changes already in the repo folder:"
                print_status_lines $info_changes
            else
                say_ok "No uncommitted changes currently in the repo folder."
            end
            echo ""
            print_scheduled_tasks
            set_color cyan
            echo "--- Commit Log Stats ---"
            set_color normal
            if not test -f "$log_file"
                say_warn "No log file found yet at $log_file"
            else
                set info_total_lines (count (cat "$log_file"))
                set info_current_month (date "+%Y-%m")
                set info_month_lines (grep -c "^\[$info_current_month" "$log_file" 2>/dev/null; or echo 0)
                set info_first_line (head -n 1 "$log_file")
                set info_last_line (tail -n 1 "$log_file")
                echo "Total logged commits: $info_total_lines"
                echo "Commits this month:   $info_month_lines"
                echo ""
                echo "First logged commit:"
                echo "  $info_first_line"
                echo "Most recent commit:"
                echo "  $info_last_line"
            end
            exit 0
    end
end

if not test -d "$REPO_PATH"
    say_err "REPO_PATH does not exist: $REPO_PATH"
    exit 1
end

if not test -d "$REPO_PATH/.git"
    say_err "REPO_PATH is not a git repository: $REPO_PATH"
    exit 1
end

set malformed_folders 0
for folder in $SYNC_FOLDERS
    set colon_count (string match -ar ":" -- "$folder" | count)
    if test $colon_count -eq 0
        say_err "Malformed SYNC_FOLDERS entry: $folder"
        set malformed_folders 1
    end
end

if test $malformed_folders -eq 1
    exit 1
end

set missing_sources 0
for folder in $SYNC_FOLDERS
    set src (echo $folder | cut -d ':' -f1)
    if not test -d "$src"
        say_err "Sync source does not exist: $src"
        set missing_sources 1
    end
end

if test $missing_sources -eq 1
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

function print_status_lines
    for line in $argv
        set x (string sub -l 1 -- $line)
        set y (string sub -s 2 -l 1 -- $line)
        set fpath (string sub -s 4 -- $line)
        if test "$x" != " "
            set letter "$x"
            set_color green
        else
            set letter "$y"
            switch $letter
                case "M"
                    set_color red
                case "D"
                    set_color red
                case "?"
                    set_color yellow
                case '*'
                    set_color normal
            end
        end
        printf "%-2s " "$letter"
        set_color normal
        echo "$fpath"
    end
end

function print_banner
    set_color cyan
    echo ""
    echo "========================================="
    echo "   $PACK_NAME — GitHub Commit Script"
    echo "   Syncs and commits pack changes"
    echo "   Made by $AUTHOR_NAME"
    echo "   Discord: $DISCORD_LINK"
    echo "   Version: $TOOL_VERSION"
    get_last_sync_line
    set repo_remote_url (git -C "$REPO_PATH" config --get remote.origin.url 2>/dev/null)
    set repo_slug (string replace -r '\.git$' '' -- "$repo_remote_url")
    set repo_slug (string replace -r '^.*[:/]([^/]+/[^/]+)$' '$1' -- "$repo_slug")
    set repo_total_commits (git -C "$REPO_PATH" rev-list --count HEAD 2>/dev/null)
    if test -n "$repo_slug"
        echo "   Repo: $repo_slug ($repo_total_commits commits)"
    end
    if test $dry_run -eq 1
        echo "   [DRY RUN — nothing will be committed or pushed]"
    end
    echo "========================================="
    echo ""
    set_color normal
end

function schedule_background_push
    set target_time $argv[1]
    set target_epoch (date -d "$target_time" +%s 2>/dev/null)
    if test -z "$target_epoch"
        return 1
    end
    set now_epoch (date +%s)
    if test $target_epoch -le $now_epoch
        set target_epoch (math $target_epoch + 86400)
    end
    set target_time_fmt (date -d @$target_epoch "+%H:%M")
    say_ok "Push scheduled for $target_time_fmt in background."
    say_info "You can continue working or making new commits, safely close this window anytime."
    mkdir -p "$log_dir"

    nohup fish -c "
        while true
            set cur_epoch (date +%s)
            if test \$cur_epoch -ge $target_epoch
                break
            end
            sleep 1
        end
        cd '$REPO_PATH'
        set lock_wait_start (date +%s)
        set lock_acquired 0
        while true
            set current_state (cat .git/pack_commit_sync_state 2>/dev/null)
            if test -z \"\$current_state\"; or test \"\$current_state\" = \"IDLE\"
                echo \"BG_RUNNING:\$fish_pid\" > .git/pack_commit_sync_state
                sleep 1
                set verify_state (cat .git/pack_commit_sync_state 2>/dev/null)
                if test \"\$verify_state\" = \"BG_RUNNING:\$fish_pid\"
                    set lock_acquired 1
                    break
                end
            end
            set now_epoch (date +%s)
            if test (math \$now_epoch - \$lock_wait_start) -ge 600
                break
            end
            sleep 3
        end
        if test \$lock_acquired -eq 0
            echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] [$PACK_NAME] [SCHEDULED PUSH FAILED] Timed out waiting for the script to be idle.\" >> '$log_file'
            if test -f '$log_dir/scheduled_tasks'
                set remaining (grep -v \"^\$fish_pid|\" '$log_dir/scheduled_tasks' 2>/dev/null)
                if test -n \"\$remaining\"
                    printf \"%s\n\" \$remaining > '$log_dir/scheduled_tasks'
                else
                    rm -f '$log_dir/scheduled_tasks'
                end
            end
            exit 1
        end
        git fetch --quiet 2>/dev/null
        set bg_pull_ok 0
        for bg_attempt in 1 2 3
            if git pull --rebase -X theirs --quiet 2>/dev/null
                set bg_pull_ok 1
                break
            end
            git rebase --abort >/dev/null 2>&1
            sleep 2
        end
        if test \$bg_pull_ok -eq 0
            echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] [$PACK_NAME] [SCHEDULED PUSH FAILED] Pull/rebase failed (possible conflict).\" >> '$log_file'
            echo \"IDLE\" > .git/pack_commit_sync_state
            if test -f '$log_dir/scheduled_tasks'
                set remaining (grep -v \"^\$fish_pid|\" '$log_dir/scheduled_tasks' 2>/dev/null)
                if test -n \"\$remaining\"
                    printf \"%s\n\" \$remaining > '$log_dir/scheduled_tasks'
                else
                    rm -f '$log_dir/scheduled_tasks'
                end
            end
            exit 1
        end
        set sched_msgs (git log --format='%s' '@{u}..HEAD' 2>/dev/null)
        if git push --quiet 2>/dev/null
            for msg in \$sched_msgs
                echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] [$PACK_NAME] [SCHEDULED PUSH] \$msg\" >> '$log_file'
            end
        else
            echo \"[\$(date '+%Y-%m-%d %H:%M:%S')] [$PACK_NAME] [SCHEDULED PUSH FAILED] Push failed (network or auth issue).\" >> '$log_file'
        end
        echo \"IDLE\" > .git/pack_commit_sync_state
        if test -f '$log_dir/scheduled_tasks'
            set remaining (grep -v \"^\$fish_pid|\" '$log_dir/scheduled_tasks' 2>/dev/null)
            if test -n \"\$remaining\"
                printf \"%s\n\" \$remaining > '$log_dir/scheduled_tasks'
            else
                rm -f '$log_dir/scheduled_tasks'
            end
        end
    " </dev/null >/dev/null 2>&1 &

    set bg_pid $last_pid
    echo "$bg_pid|$target_time_fmt" >> "$log_dir/scheduled_tasks"

    disown
    return 0
end

function print_branch
    set_color yellow
    echo "Current branch: $current_branch"
    set_color normal
    echo ""
end

function redraw_sync_status
    clear
    print_banner
    print_branch
    print_scheduled_tasks
    echo ""
    set_color yellow
    echo "Files changed since last commit:"
    set_color normal
    print_status_lines (git status --short)
    echo ""
end

function pause_continue
    if test (count $argv) -gt 0
        echo "$argv"
    else
        echo "Press Enter to continue."
    end
    read
end

function pause_close
    echo ""
    echo "Press Enter to close."
    read
    exit $argv[1]
end

function read_idle
    set_sync_state "IDLE"
    read -g -P "> " $argv[1]
    set_sync_state "ACTIVE"
end

function safe_pull_rebase
    git fetch --quiet 2>/dev/null
    set behind_count (git rev-list --count 'HEAD..@{u}' 2>/dev/null)
    if test -z "$behind_count"; or test "$behind_count" -eq 0
        return 0
    end
    set had_stash 0
    set local_changes (git status --short)
    if test -n "$local_changes"
        say_info "Temporarily stashing uncommitted changes before pulling:"
        for line in $local_changes
            echo "  $line"
        end
        git stash push -u -m "pack-commit auto-stash before rebase" > /dev/null
        set had_stash 1
    end
    set max_attempts 3
    set attempt 1
    set pull_status 1
    while test $attempt -le $max_attempts
        git pull --rebase -X theirs
        set pull_status $status
        if test $pull_status -eq 0
            break
        end
        git rebase --abort >/dev/null 2>&1
        if test $attempt -lt $max_attempts
            sleep 2
        end
        set attempt (math $attempt + 1)
    end
    if test $had_stash -eq 1
        if git stash pop > /dev/null
            say_ok "Restored stashed changes:"
            for line in $local_changes
                echo "  $line"
            end
        else
            say_err "Could not automatically restore your stashed changes."
        end
    end
    return $pull_status
end

function do_sync
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
end

function colorize_stat_line
    set line $argv
    set stat_parts (string split ", " -- $line)
    set total_stat_parts (count $stat_parts)
    for j in (seq 1 $total_stat_parts)
        set part $stat_parts[$j]
        if string match -q "*insertion*" -- $part
            set_color green
            echo -n "$part"
            set_color normal
        else if string match -q "*deletion*" -- $part
            set_color red
            echo -n "$part"
            set_color normal
        else
            echo -n "$part"
        end
        if test $j -lt $total_stat_parts
            echo -n ", "
        end
    end
    echo ""
end

function compute_folder_tag
    set files $argv
    set touched
    for folder in $SYNC_FOLDERS
        set dest (echo $folder | cut -d ':' -f2)
        set folder_name (basename "$dest")
        for f in $files
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

function get_head_folder_tag
    compute_folder_tag (git diff-tree --no-commit-id --name-only -r HEAD)
end

function set_sync_state
    echo $argv[1] > "$REPO_PATH/.git/pack_commit_sync_state"
end

function cleanup_sync_state --on-event fish_exit --on-signal INT
    rm -f "$REPO_PATH/.git/pack_commit_sync_state"
end

clear
print_banner
cd "$REPO_PATH"
set_sync_state "ACTIVE"

if test -d "$REPO_PATH/.git/rebase-merge"; or test -d "$REPO_PATH/.git/rebase-apply"
    say_err "A rebase is already in progress in $REPO_PATH."
    pause_close 1
end

set orphaned_stash (git -C "$REPO_PATH" stash list 2>/dev/null | string match "*pack-commit auto-stash*")
if test -n "$orphaned_stash"
    say_err "Found a leftover stash from a previous interrupted run:"
    for line in $orphaned_stash
        echo "  $line"
    end
    pause_close 1
end

set current_branch (git rev-parse --abbrev-ref HEAD)
print_branch
print_scheduled_tasks

set skip_pending_print 0
while true
    tput sc
    set pending_count (git rev-list --count '@{u}..HEAD' 2>/dev/null)
    if test -z "$pending_count"; or test "$pending_count" -eq 0
        break
    end

    if test $skip_pending_print -eq 0
        say_warn "You have $pending_count commit(s) not yet pushed from a previous run:"
        git log --oneline --stat-graph-width=20 '@{u}..HEAD'
        echo ""
    end

    set skip_pending_print 0

    echo "Push these now? [Y/n], 'undo' (last), 'undo all', 'amend' (last), 'undo N'/'amend N' (e.g. 'amend 1'), or 'schedule HH:MM':"
    read_idle pending_push_confirm

    if string match -qr '^schedule ([0-9]{1,2}:[0-9]{2})$' -- "$pending_push_confirm"
        set sched_time_str (string replace -r '^schedule ' '' -- "$pending_push_confirm")
        if schedule_background_push "$sched_time_str"
            echo ""
            pause_continue "Press Enter to proceed to sync."
            break
        end
        say_err "Couldn't parse time. Use HH:MM format."
        set skip_pending_print 1
        continue
    end

    if test "$pending_push_confirm" = "undo all"
        git reset --soft "HEAD~$pending_count"
        say_ok "Removed all pending commits (changes are kept, now staged)."
        continue
    end

    if test "$pending_push_confirm" = "undo"
        git reset --soft HEAD~1
        say_ok "Removed the last local commit (changes kept staged)."
        continue
    end

    if test "$pending_push_confirm" = "amend"
        echo "Enter the corrected commit message:"
        read_idle new_msg
        if test -z "$new_msg"
            say_warn "Cancelled."
            set skip_pending_print 1
            continue
        end
        set folder_tag (get_head_folder_tag)
        if test -n "$folder_tag"
            set new_msg "$folder_tag $new_msg"
        end
        git commit --amend -m "$new_msg"
        say_ok "Commit message updated."
        set skip_pending_print 1
        continue
    end

    if string match -qr '^(undo|amend) ([0-9]+)$' -- "$pending_push_confirm"
        set action (string replace -r '^(undo|amend) ([0-9]+)$' '$1' -- "$pending_push_confirm")
        set target_idx (string replace -r '^(undo|amend) ([0-9]+)$' '$2' -- "$pending_push_confirm")

        if test $target_idx -ge 1; and test $target_idx -le $pending_count
            set session_commits (git rev-list --reverse --max-count=$pending_count HEAD)
            set target_hash (string sub -l 7 $session_commits[$target_idx])

            if test "$action" = "amend"
                echo "Enter corrected message for commit $target_idx:"
                read_idle new_msg
                if test -z "$new_msg"; say_warn "Cancelled."; set skip_pending_print 1; continue; end

                set staged_files (git diff-tree --no-commit-id --name-only -r $target_hash)
                set folder_tag (compute_folder_tag $staged_files)
                if test -n "$folder_tag"; and not string match -q "$folder_tag*" -- "$new_msg"
                    set new_msg "$folder_tag $new_msg"
                end

                if test $target_idx -eq $pending_count
                    if git commit -q --amend -m "$new_msg"
                        say_ok "Commit $target_idx amended."
                    else
                        say_err "Amend failed."
                    end
                else
                    set had_rebase_stash 0
                    set check_status (git status --short)
                    if test (count $check_status) -gt 0
                        git stash push -q -u -m "pack-commit temp stash before rebase"
                        set had_rebase_stash 1
                    end

                    if not env GIT_SEQUENCE_EDITOR="perl -pi -e 's/^pick $target_hash\w*/edit $target_hash/'" git rebase -i -q "HEAD~$pending_count" >/dev/null 2>&1
                        say_err "Rebase failed to start. Aborting."
                        git rebase --abort >/dev/null 2>&1
                        if test $had_rebase_stash -eq 1; git stash pop -q >/dev/null 2>&1; end
                        set skip_pending_print 1
                        continue
                    end

                    if not git commit -q --amend -m "$new_msg"
                        say_err "Amend failed. Aborting rebase."
                        git rebase --abort >/dev/null 2>&1
                        if test $had_rebase_stash -eq 1; git stash pop -q >/dev/null 2>&1; end
                        set skip_pending_print 1
                        continue
                    end

                    if not git rebase --continue >/dev/null 2>&1
                        say_err "Rebase failed to complete (possible conflict). Aborting."
                        git rebase --abort >/dev/null 2>&1
                        if test $had_rebase_stash -eq 1; git stash pop -q >/dev/null 2>&1; end
                        set skip_pending_print 1
                        continue
                    end

                    if test $had_rebase_stash -eq 1
                        git stash pop -q >/dev/null 2>&1
                    end

                    say_ok "Commit $target_idx amended."
                end
                set skip_pending_print 1
            else
                if test $target_idx -eq $pending_count
                    git reset -q --soft HEAD~1
                    say_ok "Commit $target_idx undone. Its changes are staged."
                else
                    set had_rebase_stash 0
                    set check_status (git status --short)
                    if test (count $check_status) -gt 0
                        git stash push -q -u -m "pack-commit temp stash before rebase"
                        set had_rebase_stash 1
                    end

                    set current_head (git rev-parse HEAD)

                    if not env GIT_SEQUENCE_EDITOR="perl -pi -e 's/^pick $target_hash\w*/drop/'" git rebase -i -q "HEAD~$pending_count" >/dev/null 2>&1
                        say_err "Failed to drop commit. Aborting rebase."
                        git rebase --abort >/dev/null 2>&1
                        if test $had_rebase_stash -eq 1; git stash pop -q >/dev/null 2>&1; end
                        set skip_pending_print 1
                        continue
                    end

                    set new_head (git rev-parse HEAD)
                    git reset -q --hard $current_head
                    git reset -q --soft $new_head

                    if test $had_rebase_stash -eq 1
                        git stash pop -q >/dev/null 2>&1
                    end

                    say_ok "Commit $target_idx undone. Its changes are staged."
                end
                set skip_pending_print 1
            end
        else
            say_warn "Invalid commit number. Must be between 1 and $pending_count."
            pause_continue "Press Enter to retype."
            clear
            print_banner
            print_branch
            print_scheduled_tasks
        end
        continue
    end

    if test "$pending_push_confirm" = "n"; or test "$pending_push_confirm" = "N"
        say_warn "Skipped."
        echo ""
        pause_continue "Press Enter to proceed to sync."
        break
    end

    if not test -z "$pending_push_confirm"; and not test "$pending_push_confirm" = "y"; and not test "$pending_push_confirm" = "Y"
        say_warn "Unrecognized input '$pending_push_confirm'. Try again."
        pause_continue "Press Enter to retype."
        clear
        print_banner
        print_branch
        print_scheduled_tasks
        continue
    end

    say_info "Pulling latest changes first..."
    if not safe_pull_rebase
        say_err "git pull --rebase failed, likely due to a conflict."
        pause_close 1
    end
    set pending_msgs (git log --format="%s" '@{u}..HEAD')
    git push
    say_ok "Pending commits pushed."
    mkdir -p "$log_dir"
    for msg in $pending_msgs
        echo "[$run_timestamp] [$PACK_NAME] [PENDING PUSH] $msg" >> "$log_file"
    end
    echo ""
    pause_continue "Press Enter to proceed to sync."
    break
end

while true
    clear
    print_banner
    print_branch
    print_scheduled_tasks

    set no_changes_choice ""
    while true
        do_sync
        set changes (git status --short)
        if test -n "$changes"
            break
        end

        if test $dry_run -eq 1
            say_info "No changes detected. (dry run)"
            pause_close 0
        end

        say_warn "No changes detected since last commit."
        echo "Press Enter to close, type 'r' to check again, or 'help' for usage info:"

        set_sync_state "IDLE"

        if test -f "$log_dir/scheduled_tasks"
            set no_changes_choice ""
            while true
                set no_changes_choice (timeout 5 fish -c 'read -P "> " line 2>/dev/null; and echo -n $line')
                if test $status -eq 0
                    break
                end
                if not test -f "$log_dir/scheduled_tasks"
                    set no_changes_choice "r"
                    break
                end
            end
        else
            read -P "> " no_changes_choice
        end

        set printed_wait 0
        while true
            set check_state (cat "$REPO_PATH/.git/pack_commit_sync_state" 2>/dev/null)
            if not string match -q "BG_RUNNING:*" -- "$check_state"
                break
            end
            if test $printed_wait -eq 0
                echo ""
                say_info "Waiting for background scheduled task to finish pushing..."
                set printed_wait 1
            end
            sleep 2
        end
        set_sync_state "ACTIVE"

        if test "$no_changes_choice" = "help"; or test "$no_changes_choice" = "--help"
            echo ""
            echo "Usage:"
            echo "  'r'     — re-sync folders and check for changes again"
            echo "  Enter   — close the script"
            echo ""
            pause_continue
            clear
            print_banner
            print_branch
            print_scheduled_tasks
        else if test -z "$no_changes_choice"
            pause_close 0
        else if test "$no_changes_choice" = "r"
            clear
            print_banner
            print_branch
            print_scheduled_tasks
        end
    end

    echo ""
    set_color yellow
    echo "Files changed since last commit:"
    set_color normal
    print_status_lines (git status --short)
    echo ""
    set changed_file_count (count (git status --short))

    if test $dry_run -eq 1
        say_info "Dry run complete. No commits or pushes made."
        pause_close 0
    end

    set valid_input 0
    set do_resync 0
    while test $valid_input -eq 0
        echo "How many separate commits do you want to split these changes into? (default 1, type 'help' for info, 'r' to re-sync, 'exit' to close without committing)"
        read_idle commit_count

        if test "$commit_count" = "exit"
            say_info "Closing without committing."
            pause_close 0
        else if test "$commit_count" = "r"
            echo ""
            say_info "Re-syncing..."
            set do_resync 1
            break
        else if test "$commit_count" = "help"; or test "$commit_count" = "--help"
            echo ""
            echo "Usage:"
            echo "  Enter a number to split your changes into that many separate commits."
            echo "  Press Enter (blank) for 1 commit containing everything."
            echo "  Type 'r' to re-sync and check for new file changes."
            echo "  Type 'exit' to close the script without committing anything."
            echo ""
            echo "  If splitting into more than 1 commit, you'll be asked which files"
            echo "  go in each round, by entering file numbers separated by spaces."
            echo "  Ranges like 1-5 also work, and can be mixed with single numbers."
            echo "  Press Enter there for everything remaining."
            echo ""
            pause_continue
            redraw_sync_status
        else
            if test -z "$commit_count"
                set commit_count 1
                set valid_input 1
            else if string match -qr '^[0-9]+$' -- "$commit_count"
                if test "$changed_file_count" -eq 1; and test "$commit_count" -gt 1
                    echo ""
                    say_warn "Only 1 file changed."
                    pause_continue
                    redraw_sync_status
                else
                    set valid_input 1
                end
            else
                echo ""
                say_warn "Invalid input."
                pause_continue
                redraw_sync_status
            end
        end
    end

    if test $do_resync -eq 1
        continue
    end

    git reset > /dev/null
    set committed_messages

    for i in (seq 1 $commit_count)
        echo ""
        set_color cyan
        echo "--- Commit $i of $commit_count ---"
        set_color normal
        set remaining_status (git status --short)
        if test -z "$remaining_status"; or test "$changed_file_count" -eq 1
            set commit_paths "-A"
        else
            set remaining_paths
            set idx 1
            set total_remaining (count $remaining_status)
            set idx_width (string length -- "$total_remaining")
            echo "Remaining changed files:"
            for line in $remaining_status
                set fpath (string sub -s 4 -- $line)
                set -a remaining_paths "$fpath"
                set padded_idx (string pad -w $idx_width -- "$idx")
                echo "  $padded_idx) $line"
                set idx (math $idx + 1)
            end
            set picker_valid 0
            set lines_to_clear 0
            while test $picker_valid -eq 0
                if test $lines_to_clear -gt 0
                    tput cuu $lines_to_clear
                    tput ed
                    set lines_to_clear 0
                end
                echo "Enter numbers separated by spaces (ranges like 1-5 also work), or press Enter for everything remaining:"
                read_idle picker_raw
                if test -z "$picker_raw"
                    set commit_paths "-A"
                    set picker_valid 1
                else
                    set commit_paths
                    set invalid_tokens
                    set expanded_tokens
                    for n in (string split " " -- $picker_raw)
                        if string match -qr '^[0-9]+-[0-9]+$' -- "$n"
                            set range_start (string split -- "-" $n)[1]
                            set range_end (string split -- "-" $n)[2]
                            if test $range_start -le $range_end
                                for r in (seq $range_start $range_end)
                                    set -a expanded_tokens "$r"
                                end
                            else
                                set -a expanded_tokens "$n"
                            end
                        else
                            set -a expanded_tokens "$n"
                        end
                    end
                    for n in $expanded_tokens
                        if string match -qr '^[0-9]+$' -- "$n"
                            set chosen $remaining_paths[$n]
                            if test -n "$chosen"
                                if not contains "$chosen" $commit_paths
                                    set -a commit_paths "$chosen"
                                end
                            else
                                set -a invalid_tokens "$n"
                            end
                        else
                            set -a invalid_tokens "$n"
                        end
                    end
                    set invalid_line_count 0
                    if test (count $invalid_tokens) -gt 0
                        echo "Invalid input: "(string join ", " -- $invalid_tokens)", skipping."
                        set invalid_line_count 1
                    end
                    if test (count $commit_paths) -eq 0
                        echo "No valid selections were made."
                        pause_continue
                        set lines_to_clear (math 5 + $invalid_line_count)
                    else
                        set picker_valid 1
                    end
                end
            end
        end

        set commit_msg ""
        set skip_round 0

        if test "$commit_paths" = "-A"
            set preview_files (git diff --name-only) (git diff --cached --name-only)
        else
            set preview_files $commit_paths
        end
        set preview_tag (compute_folder_tag $preview_files)
        if test -z "$preview_tag"; and test (count $preview_files) -gt 0
            say_warn "None of these files match a known folder in SYNC_FOLDERS:"
            for f in $preview_files
                echo "  $f"
            end
            echo "Continue without a folder tag? [Y/n]"
            read_idle tag_confirm
            if test "$tag_confirm" = "n"; or test "$tag_confirm" = "N"
                set skip_round 1
            end
        end

        while test -z "$commit_msg"; and test $skip_round -eq 0
            tput sc
            echo "Enter commit message for commit $i (or type 'history' to reuse a recent one, 'skip' to skip this round):"
            read -P "> " commit_msg_raw
            if test -z "$commit_msg_raw"
                say_warn "Commit message cannot be empty. Try again."
                pause_continue "Press Enter to retype."
                tput rc
                tput ed
                continue
            end
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
                    read_idle history_choice

                    if string match -qr '^[0-9]+$' -- "$history_choice"
                        set chosen_line $recent_msgs[$history_choice]
                        if test -n "$chosen_line"
                            set commit_msg (string replace -r '^\[.*?\]\s*\[.*?\]\s*(\[(PENDING PUSH|SCHEDULED PUSH|SCHEDULED)\]\s*)?' '' -- "$chosen_line")

                            set valid_tags
                            for folder in $SYNC_FOLDERS
                                set -a valid_tags (basename (echo "$folder" | cut -d ':' -f2))
                            end
                            set tag_pattern (string join "|" $valid_tags)
                            set tag_regex '^\[('"$tag_pattern"')(,\s*('"$tag_pattern"'))*\]\s*'

                            set commit_msg (string replace -r $tag_regex '' -- "$commit_msg")
                        else
                            echo "Invalid number, try again."
                        end
                    else
                        set commit_msg "$history_choice"
                    end
                else
                    echo "No log file yet."
                end
            else
                set commit_msg "$commit_msg_raw"
            end
        end

        if test $skip_round -eq 1
            say_warn "Skipped commit $i."
            continue
        end

        git add $commit_paths
        set staged_files (git diff --cached --name-only)
        set folder_tag (compute_folder_tag $staged_files)
        if test -n "$folder_tag"
            set commit_msg "$folder_tag $commit_msg"
        end
        set commit_desc ""
        echo "Add an extended description? (optional — press Enter to skip, or type lines and press Enter on a blank line when done):"
        set desc_lines
        while true
            read_idle desc_line
            if test -z "$desc_line"
                break
            end
            set -a desc_lines "$desc_line"
        end
        if test (count $desc_lines) -gt 0
            set tmp_msg_file (mktemp)
            echo "$commit_msg" > "$tmp_msg_file"
            echo "" >> "$tmp_msg_file"
            printf "%s\n" $desc_lines >> "$tmp_msg_file"
            set commit_output (git commit -F "$tmp_msg_file")
            rm -f "$tmp_msg_file"
        else
            set commit_output (git commit -m "$commit_msg")
        end

        set commit_status $status

        if test $commit_status -eq 0
            for line in $commit_output
                if string match -q "*insertion*" -- $line; or string match -q "*deletion*" -- $line
                    colorize_stat_line "$line"
                else
                    echo "$line"
                end
            end
            set -a committed_messages "$commit_msg"
        else
            say_warn "Nothing was actually committed for this round."
        end
    end

    set commit_num_made (count $committed_messages)
    set goto_sync_check 0

    while true
        tput sc
        if test $commit_num_made -eq 0
            say_warn "No commits left to push."
            set goto_sync_check 1
            break
        end

        echo ""
        set_color yellow
        echo "About to push $commit_num_made commit(s). [Y/n], 'undo' (last), 'undo all', 'amend' (last), 'undo N'/'amend N' (e.g. 'amend 1'), or 'schedule HH:MM':"
        set_color normal
        read_idle push_confirm

        if string match -qr '^schedule ([0-9]{1,2}:[0-9]{2})$' -- "$push_confirm"
            set sched_time_str (string replace -r '^schedule ' '' -- "$push_confirm")
            if schedule_background_push "$sched_time_str"
                for msg in $committed_messages
                    echo "[$run_timestamp] [$PACK_NAME] [SCHEDULED] $msg" >> "$log_file"
                end
                set goto_sync_check 1
                break
            end
            say_err "Couldn't parse time. Use HH:MM format."
            continue
        end

        if test "$push_confirm" = "undo all"
            git reset --soft "HEAD~$commit_num_made"
            set committed_messages
            set commit_num_made 0
            say_ok "Removed all commits made this run (changes are kept, now staged)."
            continue
        end

        if test "$push_confirm" = "undo"
            git reset --soft HEAD~1
            set -e committed_messages[-1]
            set commit_num_made (count $committed_messages)
            say_ok "Removed the last commit made this run."
            continue
        end

        if test "$push_confirm" = "amend"
            echo "Enter the corrected commit message:"
            read_idle new_msg
            if test -n "$new_msg"
                set folder_tag (get_head_folder_tag)
                if test -n "$folder_tag"
                    set new_msg "$folder_tag $new_msg"
                end
                git commit -q --amend -m "$new_msg"
                set committed_messages[-1] "$new_msg"
                say_ok "Commit message updated."
            end
            continue
        end

        if string match -qr '^(undo|amend) ([0-9]+)$' -- "$push_confirm"
            set action (string replace -r '^(undo|amend) ([0-9]+)$' '$1' -- "$push_confirm")
            set target_idx (string replace -r '^(undo|amend) ([0-9]+)$' '$2' -- "$push_confirm")

            if test $target_idx -ge 1; and test $target_idx -le $commit_num_made
                set session_commits (git rev-list --reverse --max-count=$commit_num_made HEAD)
                set target_hash (string sub -l 7 $session_commits[$target_idx])

                if test "$action" = "amend"
                    echo "Enter corrected message for commit $target_idx:"
                    read_idle new_msg
                    if test -z "$new_msg"; say_warn "Cancelled."; continue; end

                    set staged_files (git diff-tree --no-commit-id --name-only -r $target_hash)
                    set folder_tag (compute_folder_tag $staged_files)
                    if test -n "$folder_tag"; and not string match -q "$folder_tag*" -- "$new_msg"
                        set new_msg "$folder_tag $new_msg"
                    end

                    if test $target_idx -eq $commit_num_made
                        if git commit -q --amend -m "$new_msg"
                            set committed_messages[$target_idx] "$new_msg"
                            say_ok "Commit $target_idx amended."
                        else
                            say_err "Amend failed."
                        end
                    else
                        set had_rebase_stash 0
                        set check_status (git status --short)
                        if test (count $check_status) -gt 0
                            git stash push -q -u -m "pack-commit temp stash before rebase"
                            set had_rebase_stash 1
                        end

                        if not env GIT_SEQUENCE_EDITOR="perl -pi -e 's/^pick $target_hash\w*/edit $target_hash/'" git rebase -i -q "HEAD~$commit_num_made" >/dev/null 2>&1
                            say_err "Rebase failed to start. Aborting."
                            git rebase --abort >/dev/null 2>&1
                            if test $had_rebase_stash -eq 1; git stash pop -q >/dev/null 2>&1; end
                            continue
                        end

                        if not git commit -q --amend -m "$new_msg"
                            say_err "Amend failed. Aborting rebase."
                            git rebase --abort >/dev/null 2>&1
                            if test $had_rebase_stash -eq 1; git stash pop -q >/dev/null 2>&1; end
                            continue
                        end

                        if not git rebase --continue >/dev/null 2>&1
                            say_err "Rebase failed to complete (possible conflict). Aborting."
                            git rebase --abort >/dev/null 2>&1
                            if test $had_rebase_stash -eq 1; git stash pop -q >/dev/null 2>&1; end
                            continue
                        end

                        if test $had_rebase_stash -eq 1
                            git stash pop -q >/dev/null 2>&1
                        end

                        set committed_messages[$target_idx] "$new_msg"
                        say_ok "Commit $target_idx amended."
                    end
                else
                    if test $target_idx -eq $commit_num_made
                        git reset -q --soft HEAD~1
                        set -e committed_messages[$target_idx]
                        set commit_num_made (count $committed_messages)
                        say_ok "Commit $target_idx undone. Its changes are staged."
                    else
                        set had_rebase_stash 0
                        set check_status (git status --short)
                        if test (count $check_status) -gt 0
                            git stash push -q -u -m "pack-commit temp stash before rebase"
                            set had_rebase_stash 1
                        end

                        set current_head (git rev-parse HEAD)

                        if not env GIT_SEQUENCE_EDITOR="perl -pi -e 's/^pick $target_hash\w*/drop/'" git rebase -i -q "HEAD~$commit_num_made" >/dev/null 2>&1
                            say_err "Failed to drop commit. Aborting rebase."
                            git rebase --abort >/dev/null 2>&1
                            if test $had_rebase_stash -eq 1; git stash pop -q >/dev/null 2>&1; end
                            continue
                        end

                        set new_head (git rev-parse HEAD)
                        git reset -q --hard $current_head
                        git reset -q --soft $new_head

                        if test $had_rebase_stash -eq 1
                            git stash pop -q >/dev/null 2>&1
                        end

                        set -e committed_messages[$target_idx]
                        set commit_num_made (count $committed_messages)
                        say_ok "Commit $target_idx undone. Its changes are staged."
                    end
                end
            else
                say_warn "Invalid commit number. Must be between 1 and $commit_num_made."
                pause_continue "Press Enter to retype."
                tput rc
                tput ed
            end
            continue
        end

        if test "$push_confirm" = "n"; or test "$push_confirm" = "N"
            break
        end

        if test -z "$push_confirm"; or test "$push_confirm" = "y"; or test "$push_confirm" = "Y"
            break
        end

        say_warn "Unrecognized input '$push_confirm'. Try again."
        pause_continue "Press Enter to retype."
        tput rc
        tput ed
        continue
    end

    if test $goto_sync_check -eq 1
        continue
    end

    if test "$push_confirm" = "n"; or test "$push_confirm" = "N"
        say_warn "Push skipped. Your commits are saved locally."
        pause_continue "Press Enter to return to the start."
        continue
    end

    say_info "Pulling latest changes first..."
    if not safe_pull_rebase
        say_err "git pull --rebase failed, likely due to a conflict."
        pause_close 1
    end

    say_info "Pushing to GitHub..."
    git push

    echo ""
    say_ok "Done! Commits pushed this run:"
    git log --oneline -$commit_num_made

    echo ""
    set shortstat_line (git diff --shortstat "HEAD~$commit_num_made" HEAD)
    if test -n "$shortstat_line"
        colorize_stat_line "$shortstat_line"
    end

    set script_end_time (date +%s)
    set elapsed (math $script_end_time - $script_start_time)
    set elapsed_mins (math -s0 "$elapsed / 60")
    set elapsed_secs (math -s0 "$elapsed % 60")
    if test $elapsed_mins -gt 0
        echo "Run took "$elapsed_mins"m "$elapsed_secs"s"
    else
        echo "Run took "$elapsed_secs"s"
    end

    mkdir -p "$log_dir"
    for msg in $committed_messages
        echo "[$run_timestamp] [$PACK_NAME] $msg" >> "$log_file"
    end

    pause_continue "Press Enter to return to the start."
end
