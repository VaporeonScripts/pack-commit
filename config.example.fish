# Rename this file to config.fish and edit the values below.
# config.fish is gitignored by default so your personal paths never get committed.

# Display name shown in the script's banner
set PACK_NAME "My Modpack"

# Optional credits shown in the banner (delete these two lines if you don't want them)
set AUTHOR_NAME "YourName"
set DISCORD_LINK "https://discord.gg/yourinvite"

# The local path to your cloned GitHub repo (where commits actually happen)
set REPO_PATH ~/path/to/your/repo

# Folders to sync before committing, as "source:destination" pairs.
# source = where you actively edit files (your live instance/dev folder)
# destination = the matching folder inside REPO_PATH
# Add or remove lines as needed for your own pack's folder layout.
set SYNC_FOLDERS \
    ~/path/to/instance/config:$REPO_PATH/config \
    ~/path/to/instance/kubejs:$REPO_PATH/kubejs
