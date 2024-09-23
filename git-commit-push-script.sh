#!/bin/bash
source ~/.bash_profile

# Add all changes
git add -A

# Get branch name
base_branch=$(git rev-parse --abbrev-ref HEAD)

# Extract ticket number from current directory
ticket=$(echo $base_branch | grep -o -E '([A-Za-z]+-[0-9]{3,}|[A-Za-z]+-[0-9]{3,})')

echo "Ticket: $ticket"

# Get the git diff
diff=$(git diff --cached)

# Stringify the diff
diff=$(echo $diff | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\n/\\n/g')

# Prepare the Gemini API request
gemini_request='{"contents":[{"parts":[{"text": "Write a git commit message (72 character maximum) for the following git diff: '"$diff"' "}]}]}'

# Get commit message from Gemini API
commit_message=$(curl \
  -H 'Content-Type: application/json' \
  -d "$gemini_request" \
  -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${GEMINI_API_KEY}" \
  |  jq -r '.candidates[0].content.parts[0].text'
)

echo "$commit_message"

# Prepare and execute commit command
git commit -S -m "$ticket $commit_message"

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
