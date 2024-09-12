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
echo "Commit message: $ticket - $message"

# Prepare and execute commit command
git commit -S -m "$ticket - $message"

# Push changes
git push
