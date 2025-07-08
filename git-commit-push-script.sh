## Automating Staging, Committing and Pushing to GitHub with Gemini AI 👨🏻‍💻➡️
## AI commits generated from git diff 

## *** A free Gemini AI API key is required to run this shell script *** - https://www.getgemini.ai/
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

# Stringify the diff
diff=$(echo $diff | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed 's/\n/\\n/g')

# Prepare the Gemini API request
# gemini_request='{
# 	"contents":[{"parts":[{"text": "Write a git commit message title (no more than 72 characters total) for the following git diff: '"$diff"' Do not include any other text in the response."}]}],
# 	"safetySettings": [{"category": "HARM_CATEGORY_DANGEROUS_CONTENT","threshold": "BLOCK_NONE"}],
# 	"generationConfig": {
# 		"temperature": 0.2,
# 		"maxOutputTokens": 50
# 	}
# }'

# Prepare the Ollama Gemma3n API request
gemma_request='{
  "model": "gemma3n",
  "prompt": "Write a git commit message title (no more than 72 characters total) for the following git diff: '"$diff"' Do not include any other text in the response."
}'

# Request a commit message from Ollama Gemma3n local API
commit_message=$(curl http://localhost:11434/api/generate -d "$gemma_request" -H "Content-Type: application/json" | jq -r '.response')

# If the commit message is empty, retry the request
if [ -z "$commit_message" ]; then
	commit_message=$(curl -s \
	  -H 'Content-Type: application/json' \
	  -d "$gemma_request" \
	  -X POST "http://localhost:11434/api/generate" \
	  | jq -r '.response'
	  )
fi

# If the commit message is still empty, exit with an error
if [ -z "$commit_message" ]; then
	echo "Error: Ollama API request for commit message failed. Please try again."
	exit 1
fi

# # Request and parse the commit message from Gemini API
# commit_message=$(curl -s \
#   -H 'Content-Type: application/json' \
#   -d "$gemini_request" \
#   -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${GEMINI_API_KEY}" \
#   | jq -r '.candidates[0].content.parts[0].text'
#   )

# If the commit message is empty, retry the request
# if [ -z "$commit_message" ]; then
# 	commit_message=$(curl -s \
# 	  -H 'Content-Type: application/json' \
# 	  -d "$gemini_request" \
# 	  -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=${GEMINI_API_KEY}" \
# 	  | jq -r '.candidates[0].content.parts[0].text'
# 	  )
# fi

# Clean up commit message formatting - remove #, ```, period . at the end of response
commit_message=$(echo $commit_message | sed 's/#//g' | sed 's/```//g' | sed 's/Commit message title://g' | sed 's/Commit message summary://g' | sed 's/\.//g')

# Print the commit message
echo $commit_message

# # If the Gemini retry request fails, exit
# if [ -z "$commit_message" ]; then
# 	echo "Error: API request for commit message failed. Please try again."
# 	exit 1
# fi

# export COMMIT_MESSAGE="$commit_message"
# export TICKET="$ticket"
# # Prepare and execute commit command, remove -S to commit without signing
# if [ -z "$ticket" ]; then
# 	expect <<'EOF'
# spawn git commit -S -m "$env(COMMIT_MESSAGE)"
# expect "Enter passphrase for \"/Users/wscholl/.ssh/id_ed25519\":"
# send "$env(GIT_SSH_PASSPHRASE)\r"
# expect eof
# EOF
# else
# 	expect <<'EOF'
# spawn git commit -S -m "$env(TICKET) $env(COMMIT_MESSAGE)"
# expect "Enter passphrase for \"/Users/wscholl/.ssh/id_ed25519\":"
# send "$env(GIT_SSH_PASSPHRASE)\r"
# expect eof
# EOF
# fi

# # Check if the branch exists on the remote
# remote_branch=$(git ls-remote --heads origin $base_branch)

# # Function: pull_push_after_failed_push - If push fails, attempt to pull and push again
# pull_push_after_failed_push() {
# 	echo "Push failed. Attempting to pull and push again."
# 	git pull
# 	git push --force
# }

# # Check if the branch exists on the remote
# if [ -z "$remote_branch" ]; then
# 	# If the branch does not exist on the remote, create it
# 	echo "Branch '$base_branch' does not exist on remote. Creating it."
# 	# Push the local branch to the remote, setting the upstream branch
# 	git push --set-upstream origin $base_branch

# 	# Check if the push was successful, if previous command is not a failure, 
#   	# execute the function to handle a failed push
# 	if [ $? -ne 0 ]; then
# 		pull_push_after_failed_push
# 	fi
# else # Branch exists on the remote, push changes to the remote branch
# 	echo "Branch '$base_branch' exists on remote. Pushing changes."
# 	git push

# 	# Check if the push wasn't successful, execute the function to handle a failed push
# 	if [ $? -ne 0 ]; then
# 		pull_push_after_failed_push
# 	fi
# fi
