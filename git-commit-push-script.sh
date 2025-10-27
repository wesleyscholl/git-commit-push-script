## Automating Staging, Committing and Pushing to GitHub with Ollama and Mistral AI 👨🏻‍💻➡️
## AI commits generated from git diff 
## Configuration instructions: https://github.com/wesleyscholl/git-commit-push-script 

#!/bin/bash
source ~/.bash_profile

# Pre-warm the model (optional - keeps it loaded)
ollama run mistral-commit "test" > /dev/null 2>&1 &

# Stage all changes
git add -A

# Get the branch name
base_branch=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $base_branch"

# Get default branch or main branch
default_branch=$(git rev-parse --abbrev-ref origin/HEAD | sed 's@^origin/@@')
echo "Default branch: $default_branch"

# Extract Jira ticket number from current directory 
ticket=$(echo $base_branch | grep -o -E '([A-Za-z]+-[0-9]{3,}|[A-Za-z]+-[0-9]{3,})')

# Get the git diff comparing the current branch with the default branch
diff=$(git diff origin/$default_branch)
# echo "Git diff:\n\n$diff"

# # Default model (change if desired)
# MODEL="mistral-commit"

# # Prepare the prompt
# PROMPT="$diff"

# # Run the model and capture output
# COMMIT_MSG=$(ollama run "$MODEL" "$PROMPT")

# # If the commit message is empty, exit with an error
# if [ -z "$COMMIT_MSG" ]; then
# 	echo "Error: Commit message is empty. Please check the diff and try again."
# 	exit 1
# fi

# Stringify the diff
# diff=$(echo $diff | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\n/\\n/g')

# Default model (change if desired)
MODEL="gemma3:4b"

# Prepare the prompt
PROMPT=$(printf "You are an expert software engineer and technical writer. Write a clear, professional commit message based on the following Git diff. Requirements:\n- Summarize the purpose and key changes made, like if a file was created, edited, moved or deleted.\n- Include which files were created, modified, deleted (removed), or moved if applicable.\n- Do NOT include quotes, explanations, diff syntax, markdown formatting, or any additional text or formatting.\n- Limit your response to 20 tokens.\n\n Respond in the following format:\nCommit message: <Your concise commit message>\n\nGit diff:\n%s" "$diff")

# Run the model and capture output
commit_message=$(echo "$PROMPT" | ollama run "$MODEL")

# Prepare the Gemini API request
# gemini_request='{"contents":[{"parts":[{"text": "Write a git commit message title (no more than 72 characters total) for the following git diff: '"$diff"' Do not include any other text in the repsonse."}]}]}'

# # Get commit message from Gemini API
# commit_message=$(curl -s \
#   -H 'Content-Type: application/json' \
#   -d "$gemini_request" \
#   -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${GEMINI_API_KEY}" \
#   | jq -r '.candidates[0].content.parts[0].text'
#   )

# # Clean up commit message formatting - remove #, ```, "", '', ()), and period . at the end of response
commit_message=$(echo $commit_message | sed 's/#//g' | sed 's/```//g' | sed 's/Commit message title://g' | sed 's/Commit message summary://g' | sed 's/\.//g' | sed 's/\"//g' | sed "s/'//g" | sed 's/())//g' | sed 's/()//g' | sed 's/Commit message://g' | sed 's/Commit message title: //g' | sed 's/Commit message summary: //g' | sed 's/Commit message body: //g' | sed 's/Commit message body://g' | sed 's/^\s*//;s/\s*$//' | sed 's/Code Review Request://g' | sed 's/Code Review://g' | sed 's/Summary of changes://g')

echo $commit_message

if [ -z "$commit_message" ]; then
	echo "Error: API request for commit message failed. Please try again."
	exit 1
fi

# # Clean up commit message formatting - remove #, ```, "", '', ()), and period . at the end of response
# commit_message=$(echo $COMMIT_MSG | sed 's/#//g' | sed 's/```//g' | sed 's/Commit message title://g' | sed 's/Commit message summary://g' | sed 's/\.//g' | sed 's/\"//g' | sed "s/'//g" | sed 's/())//g' | sed 's/()//g' | sed 's/Commit message://g' | sed 's/Commit message title: //g' | sed 's/Commit message summary: //g' | sed 's/Commit message body: //g' | sed 's/Commit message body://g')

# # If the commit message is longer than 72 characters, truncate at the last word boundary
# if [ ${#commit_message} -gt 72 ]; then
# 	commit_message=$(echo $commit_message | cut -d' ' -f1-18)
# fi

# Echo the commit message
# echo $commit_message

# $commit_message == null ? commit_message="Updated ${base_branch} branch" : echo "Commit message: $commit_message"
# Check for null commit message and set a default if necessary
if [ "$commit_message" == "null" ] || [ -z "$commit_message" ]; then
	commit_message="Updated ${base_branch} branch"
	echo "Commit message is null or empty. Using default: $commit_message"
else
	echo "Commit message: $commit_message"
fi

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