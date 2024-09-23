#!/bin/bash
source ~/.bash_profile

# Stage all changes
git add -A

# Get branch name
base_branch=$(git rev-parse --abbrev-ref HEAD)

# Extract ticket number from current directory
ticket=$(echo $base_branch | grep -o -E '([A-Za-z]+-[0-9]{3,}|[A-Za-z]+-[0-9]{3,})')

# Get the git diff
diff=$(git diff --cached)

# Stringify the diff
diff=$(echo $diff | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\n/\\n/g')

# Prepare the Gemini API request
gemini_request='{"contents":[{"parts":[{"text": "Write a git commit message (commit message title 72 character maximum and commit message summary 50 character maxiumum) for the following git diff: '"$diff"' The format should be as follows (without titles, back ticks, markdown fomatting, or template strings): <commit message title> (2 new lines) <commit message summary> "}]}]}'

# Get commit message from Gemini API
commit_message=$(curl -s \
  -H 'Content-Type: application/json' \
  -d "$gemini_request" \
  -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${GEMINI_API_KEY}" \
  |  jq -r '.candidates[0].content.parts[0].text'
)

echo $commit_message

# Clean up commit message - remove #, ```, and any other characters other than A-Z, a-z, 0-9, spaces, and new lines
commit_message=$(echo "$commit_message" | sed 's/#//g' | sed 's/```//g' | sed 's/[^A-Za-z0-9 \n]//g')

echo $commit_message

# Prepare and execute commit command
git commit -S -m "$ticket $commit_message"

# Check if the branch exists on the remote
remote_branch=$(git ls-remote --heads origin $base_branch)

# Function: pull_push_after_failed_push - If push fails, attempt to pull and push again
pull_push_after_failed_push() {
	echo "Push failed. Attempting to pull and push again."
	git pull
	git push
}

# Check if the branch exists on the remote
if [ -z "$remote_branch" ]; then
	echo "Branch '$base_branch' does not exist on remote. Creating it."
	# Push the local branch to the remote, setting the upstream branch
	git push --set-upstream origin $base_branch

	if [ $? -ne 0 ]; then
		pull_push_after_failed_push
	fi
else
	echo "Branch '$base_branch' exists on remote. Pushing changes."
	# Push changes to the remote
	git push

	if [ $? -ne 0 ]; then
		pull_push_after_failed_push
	fi
fi
