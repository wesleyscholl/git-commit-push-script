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
gemini_request='{"contents":[{"parts":[{"text": "Write a git commit message title (no more than 72 characters total) for the following git diff: '"$diff"' Do not include any other text in the repsonse."}]}]}'

# Get commit message from Gemini API
commit_message=$(curl -s \
  -H 'Content-Type: application/json' \
  -d "$gemini_request" \
  -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${GEMINI_API_KEY}" \
  | jq -r '.candidates[0].content.parts[0].text'
  )

# Clean up commit message formatting - remove #, ```,
commit_message=$(echo $commit_message | sed 's/#//g' | sed 's/```//g' | sed 's/Commit message title://g' | sed 's/Commit message summary://g')

echo $commit_message

if [ -z "$commit_message" ]; then
	echo "Error: API request for commit message failed. Please try again."
	exit 1
fi

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
