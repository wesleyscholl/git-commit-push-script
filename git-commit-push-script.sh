#!/bin/bash

# Create the alias
alias cm='

# Add all changes
git add -A

# Extract ticket number from current directory
ticket=$(pwd | grep -oE "CRS-[0-9]+" | head -n 1)

# Prompt for commit message

echo "Enter commit message: "
read message
echo "Commit message: $ticket - $message"

# Prepare and execute commit command
git commit -S -m "$ticket - $message"

# Push changes
git push
'
