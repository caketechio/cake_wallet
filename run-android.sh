#!/bin/bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/functions.sh"
# Get the current git branch
get_current_branch() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        branch=$(git rev-parse --abbrev-ref HEAD)
        echo "$branch" | tr '-' '_'
    else
        echo "Error: Not a git repository."
        return 1
    fi
}

# Update the app.properties file
update_app_properties() {
    local branch=$1
    local file_path="./android/app.properties"
    universal_sed "s/^id=.*/id=com.cakewallet.$branch/" "$file_path"
    universal_sed "s/^name=.*/name=$branch-Cake Wallet/" "$file_path"
}

# only update app.properties if getting the current branch was successful
current_branch=$(get_current_branch)
if [[ $? -eq 0 ]]; then
    update_app_properties "$current_branch"
fi

# run the app
flutter run
