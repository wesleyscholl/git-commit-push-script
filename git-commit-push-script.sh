#!/bin/bash
source ~/.bash_profile

# Add all changes
git add -A

# Get branch name
base_branch=$(git rev-parse --abbrev-ref HEAD)

# Extract ticket number from current directory
ticket=$(echo $base_branch | grep -o -E '([A-Za-z]+-[0-9]{3,}|[A-Za-z]+-[0-9]{3,})')

# Prompt for commit message
read -p "Enter commit message: " message
echo "Commit message: $ticket $message"

# Prepare and execute commit command
git commit -S -m "$ticket $message"

# Check if the branch exists on the remote
remote_branch=$(git ls-remote --heads origin $base_branch)

if [ -z "$remote_branch" ]; then
    echo "Branch '$base_branch' does not exist on remote. Creating it."
    # Push the local branch to the remote, setting the upstream branch
    git push --set-upstream origin $base_branch
else
    echo "Branch '$base_branch' exists on remote. Pushing changes."
    # Push changes to the remote
    git push
fi
