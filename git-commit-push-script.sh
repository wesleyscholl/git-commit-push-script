## Automating Staging, Committing and Pushing to GitHub with Ollama and Mistral AI 👨🏻‍💻➡️
## AI commits generated from git diff 
## Configuration instructions: https://github.com/wesleyscholl/git-commit-push-script 

#!/bin/bash
source ~/.bash_profile

# Stage all changes
git add -A

# Get the branch name
base_branch=$(git rev-parse --abbrev-ref HEAD)

# Extract Jira ticket number from current directory 
ticket=$(echo $base_branch | grep -o -E '([A-Za-z]+-[0-9]{3,}|[A-Za-z]+-[0-9]{3,})')

# Get the git diff
diff=$(git diff --cached)

# Default model (change if desired)
MODEL="mistral"

# Prepare the prompt
PROMPT=$(printf "You are an expert software engineer.\n\nYour job is to generate a short, commit message from the following git diff.\nNo more than 72 characters total.\nOnly return the commit message. Do not include any other text.\n\nGit diff:\n%s" "$diff")

# Run the model and capture output
COMMIT_MSG=$(echo "$PROMPT" | ollama run "$MODEL")

# If the commit message is empty, exit with an error
if [ -z "$COMMIT_MSG" ]; then
	echo "Error: Commit message is empty. Please check the diff and try again."
	exit 1
fi

# Clean up commit message formatting - remove #, ```, period . at the end of response
commit_message=$(echo $COMMIT_MSG | sed 's/#//g' | sed 's/```//g' | sed 's/Commit message title://g' | sed 's/Commit message summary://g' | sed 's/\.//g')

# Echo the commit message
echo $commit_message

# Set the GIT_SSH_PASSPHRASE environment variables
export COMMIT_MESSAGE="$commit_message"
export TICKET="$ticket"

# Prepare and execute commit command, remove -S to commit without signing
if [ -z "$ticket" ]; then
	expect <<'EOF'
spawn git commit -S -m "$env(COMMIT_MESSAGE)"
expect "Enter passphrase for \"/Users/wscholl/.ssh/id_ed25519\":"
send "$env(GIT_SSH_PASSPHRASE)\r"
expect eof
EOF
else
	expect <<'EOF'
spawn git commit -S -m "$env(TICKET) $env(COMMIT_MESSAGE)"
expect "Enter passphrase for \"/Users/wscholl/.ssh/id_ed25519\":"
send "$env(GIT_SSH_PASSPHRASE)\r"
expect eof
EOF
fi

# Check if the branch exists on the remote
remote_branch=$(git ls-remote --heads origin $base_branch)

# Function: pull_push_after_failed_push - If push fails, attempt to pull and push again
pull_push_after_failed_push() {
	echo "Push failed. Attempting to pull and push again."
	git fetch origin $base_branch
	git pull
	git push --force
}

# Check if the branch exists on the remote
if [ -z "$remote_branch" ]; then
	# If the branch does not exist on the remote, create it
	echo "Branch '$base_branch' does not exist on remote. Creating it."
	# Push the local branch to the remote, setting the upstream branch
	set -e
	git push --set-upstream origin $base_branch

	# Check if the push was successful, if previous command is not a failure, execute the function to handle a failed push
	if [ $? -ne 0 ]; then
		pull_push_after_failed_push
	fi
else # Branch exists on the remote, push changes to the remote branch
	echo "Branch '$base_branch' exists on remote."
	# Pull the latest changes from the remote branch
	echo "Pulling latest changes from remote branch..."
	git fetch origin $base_branch
	git pull
	echo "Pushing changes to remote $base_branch branch..."
	git push

	# Check if the push wasn't successful, execute the function to handle a failed push
	if [ $? -ne 0 ]; then
		pull_push_after_failed_push
	fi
fi