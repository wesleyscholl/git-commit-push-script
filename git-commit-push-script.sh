#!/bin/bash
source ~/.bash_profile

# Configuration
MAX_DIFF_CHARS=2000      # Truncate diff to prevent long processing
TIMEOUT_SECONDS=10       # Max time to wait for LLM response
MAX_COMMIT_LENGTH=50     # Max characters for commit message

# Spinner animation function
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while ps -p $pid > /dev/null 2>&1; do
        for (( i=0; i<${#spinstr}; i++ )); do
            printf "\r${spinstr:$i:1} Generating commit message..."
            sleep $delay
            if ! ps -p $pid > /dev/null 2>&1; then
                break
            fi
        done
    done
    printf "\r✓ Done!                        \n"
}

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

# Get changed files for fallback message
changed_files=$(git diff --name-only origin/$default_branch | head -3)
first_file=$(echo "$changed_files" | head -1)
file_count=$(git diff --name-only origin/$default_branch | wc -l | tr -d ' ')

# Generate fallback message based on changes
if [ "$file_count" -eq 1 ]; then
    fallback_message="${first_file} updated"
elif [ "$file_count" -gt 1 ]; then
    fallback_message="${first_file} and $((file_count - 1)) other file(s) updated"
else
    fallback_message="Updated ${base_branch} branch"
fi

# Get the git diff - truncate for performance
diff=$(git diff origin/$default_branch | head -c $MAX_DIFF_CHARS)

# Skip LLM if diff is too large (use fallback)
diff_size=$(git diff origin/$default_branch | wc -c | tr -d ' ')
if [ "$diff_size" -gt 10000 ]; then
    echo "Large diff detected ($diff_size chars). Using fallback message."
    commit_message="$fallback_message"
else
    # Default model
    MODEL="gemma3:4b"

    # Optimized prompt - shorter, more direct
    PROMPT="Git commit message (max 50 chars, no quotes/formatting):
$(echo "$diff" | head -50)"

    # Run model with timeout and spinner
    echo "$PROMPT" | timeout $TIMEOUT_SECONDS ollama run "$MODEL" --verbose 2>/dev/null | head -1 > /tmp/commit_msg.txt &
    LLM_PID=$!
    spinner $LLM_PID
    wait $LLM_PID
    exit_code=$?
    commit_message=$(cat /tmp/commit_msg.txt)
    rm -f /tmp/commit_msg.txt
    
    # Check if timeout occurred or empty response
    if [ $exit_code -eq 124 ] || [ -z "$commit_message" ]; then
        echo "LLM timeout or empty response. Using fallback message."
        commit_message="$fallback_message"
    fi
fi

# Clean up commit message formatting
commit_message=$(echo "$commit_message" | sed 's/#//g' | sed 's/```//g' | sed 's/Commit message://gi' | sed 's/\.//g' | sed 's/\"//g' | sed "s/'//g" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Truncate to max length at word boundary
if [ ${#commit_message} -gt $MAX_COMMIT_LENGTH ]; then
    commit_message=$(echo "$commit_message" | cut -c1-$MAX_COMMIT_LENGTH | sed 's/[[:space:]][^[:space:]]*$//')
fi

echo "Commit message: $commit_message"

# Final fallback check
if [ -z "$commit_message" ] || [ "$commit_message" == "null" ]; then
    commit_message="$fallback_message"
    echo "Using fallback: $commit_message"
fi

# Set the environment variables
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