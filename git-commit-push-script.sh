#!/bin/bash
source ~/.bash_profile

# Configuration
MAX_DIFF_CHARS=2000      # Truncate diff to prevent long processing
TIMEOUT_SECONDS=45       # Max time to wait for LLM response (squish auto-starts server on first run)
MAX_COMMIT_LENGTH=50     # Max characters for commit message

# Squish model selection — set SQUISH_MODEL to target a specific compressed model.
# Accepts a name hint (e.g. "14b", "7b") or a full path to a model directory.
# Leave empty to let squish auto-detect (uses the first available model in ~/models).
# Examples:
#   SQUISH_MODEL="14b"                                      # matches Qwen2.5-14B-*
#   SQUISH_MODEL="$HOME/models/Qwen2.5-14B-Instruct-bf16"  # explicit path
SQUISH_MODEL="${SQUISH_MODEL:-}"

# Squish server port — override if you run multiple squish servers concurrently.
SQUISH_PORT="${SQUISH_PORT:-8000}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Animated spinner with colors
spinner() {
    local pid=$1
    local delay=0.08
    local frames=('⣾' '⣽' '⣻' '⢿' '⡿' '⣟' '⣯' '⣷')
    local colors=("$CYAN" "$BLUE" "$PURPLE" "$CYAN" "$BLUE" "$PURPLE" "$CYAN" "$BLUE")
    local i=0
    local elapsed=0
    
    while ps -p $pid > /dev/null 2>&1; do
        printf "\r${colors[$i]}${frames[$i]}${NC} ${WHITE}Generating commit message${NC}${GRAY}...${NC} ${DIM}(${elapsed}s)${NC}  "
        sleep $delay
        i=$(( (i + 1) % ${#frames[@]} ))
        elapsed=$(echo "scale=1; $elapsed + $delay" | bc)
        if ! ps -p $pid > /dev/null 2>&1; then
            break
        fi
    done
    printf "\r${GREEN}✓${NC} ${WHITE}Done!${NC}                              \n"
}

# Status messages
print_header() {
    clear
    echo ""
    echo -e "${PURPLE}█████${CYAN}╗ ${PURPLE}██${CYAN}╗   ${PURPLE}██${CYAN}╗${PURPLE}████████${CYAN}╗ ${PURPLE}██████${CYAN}╗  ${GREEN}██████${YELLOW}╗ ${GREEN}██${YELLOW}╗   ${GREEN}██${YELLOW}╗${GREEN}███████${YELLOW}╗${GREEN}██${YELLOW}╗  ${GREEN}██${YELLOW}╗${NC}"
    echo -e "${PURPLE}██${CYAN}╔══${PURPLE}██${CYAN}╗${PURPLE}██${CYAN}║   ${PURPLE}██${CYAN}║╚══${PURPLE}██${CYAN}╔══╝${PURPLE}██${CYAN}╔═══${PURPLE}██${CYAN}╗ ${GREEN}██${YELLOW}╔══${GREEN}██${YELLOW}╗${GREEN}██${YELLOW}║   ${GREEN}██${YELLOW}║${GREEN}██${YELLOW}╔════╝${GREEN}██${YELLOW}║  ${GREEN}██${YELLOW}║${NC}"
    echo -e "${PURPLE}███████${CYAN}║${PURPLE}██${CYAN}║   ${PURPLE}██${CYAN}║   ${PURPLE}██${CYAN}║   ${PURPLE}██${CYAN}║   ${PURPLE}██${CYAN}║ ${GREEN}██████${YELLOW}╔╝${GREEN}██${YELLOW}║   ${GREEN}██${YELLOW}║${GREEN}███████${YELLOW}╗${GREEN}███████${YELLOW}║${NC}"
    echo -e "${PURPLE}██${CYAN}╔══${PURPLE}██${CYAN}║${PURPLE}██${CYAN}║   ${PURPLE}██${CYAN}║   ${PURPLE}██${CYAN}║   ${PURPLE}██${CYAN}║   ${PURPLE}██${CYAN}║ ${GREEN}██${YELLOW}╔═══╝ ${GREEN}██${YELLOW}║   ${GREEN}██${YELLOW}║╚════${GREEN}██${YELLOW}║${GREEN}██${YELLOW}╔══${GREEN}██${YELLOW}║${NC}"
    echo -e "${PURPLE}██${CYAN}║  ${PURPLE}██${CYAN}║╚${PURPLE}██████${CYAN}╔╝   ${PURPLE}██${CYAN}║   ╚${PURPLE}██████${CYAN}╔╝ ${GREEN}██${YELLOW}║     ╚${GREEN}██████${YELLOW}╔╝${GREEN}███████${YELLOW}║${GREEN}██${YELLOW}║  ${GREEN}██${YELLOW}║${NC}"
    echo -e "${CYAN}╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝  ${YELLOW}╚═╝      ╚═════╝ ╚══════╝╚═╝  ╚═╝${NC}"
    echo ""
    echo -e "${DIM}${WHITE}  AI-powered git commit messages${NC}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}▸${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${GRAY}  $1${NC}"
}

# Print header
print_header

# Stage all changes
print_step "Staging changes..."
git add -A
print_success "Changes staged"

# Get the branch name
base_branch=$(git rev-parse --abbrev-ref HEAD)
print_info "Branch: ${CYAN}$base_branch${NC}"

# Get default branch or main branch
default_branch=$(git rev-parse --abbrev-ref origin/HEAD | sed 's@^origin/@@')
print_info "Default: ${GRAY}$default_branch${NC}"

# Extract Jira ticket number from current directory 
ticket=$(echo $base_branch | grep -o -E '([A-Za-z]+-[0-9]{3,}|[A-Za-z]+-[0-9]{3,})')
if [ -n "$ticket" ]; then
    print_info "Ticket: ${YELLOW}$ticket${NC}"
fi
echo ""

# Get changed files for fallback message (staged changes vs last commit)
changed_files=$(git diff --cached --name-only | head -3)
first_file=$(echo "$changed_files" | head -1)
file_count=$(git diff --cached --name-only | wc -l | tr -d ' ')

# Show changed files
print_step "Files changed: ${WHITE}$file_count${NC}"
echo "$changed_files" | while read file; do
    if [ -n "$file" ]; then
        print_info "  ${BLUE}$file${NC}"
    fi
done
if [ "$file_count" -gt 3 ]; then
    print_info "  ${GRAY}...and $((file_count - 3)) more${NC}"
fi
echo ""

# Generate fallback message based on changes
if [ "$file_count" -eq 1 ]; then
    fallback_message="${first_file} updated"
elif [ "$file_count" -gt 1 ]; then
    fallback_message="${first_file} and $((file_count - 1)) other file(s) updated"
else
    fallback_message="Updated ${base_branch} branch"
fi

# Get the git diff (staged changes vs last commit) - truncate for performance
diff=$(git diff --cached | head -c $MAX_DIFF_CHARS)

# Squish local LLM — no API key, no rate limits, no cloud
# Server auto-starts on first use (~20s), then stays alive for near-instant responses

# Build model / port flags from config vars (empty = squish auto-detects)
SQUISH_FLAGS=""
if [ -n "$SQUISH_MODEL" ]; then
    SQUISH_FLAGS="--model $SQUISH_MODEL"
fi
if [ -n "$SQUISH_PORT" ]; then
    SQUISH_FLAGS="$SQUISH_FLAGS --port $SQUISH_PORT"
fi

# ── Debug: squish availability ───────────────────────────────────────────

# squish may be a zsh alias (not visible to bash scripts) — fall back to
# calling cli.py directly with python3 if the command isn't on PATH.
SQUISH_BIN=$(command -v squish 2>/dev/null)
if [ -z "$SQUISH_BIN" ] && [ -f "/Users/wscholl/squish/cli.py" ]; then
    SQUISH_BIN="python3 /Users/wscholl/squish/cli.py"
    print_info "squish binary: ${CYAN}$SQUISH_BIN${GRAY} (alias not in bash PATH, using direct path)${NC}"
elif [ -n "$SQUISH_BIN" ]; then
    print_info "squish binary: ${CYAN}$SQUISH_BIN${NC}"
else
    print_warning "squish not found in PATH — will use fallback message"
    commit_message="$fallback_message"
fi

if [ -n "$SQUISH_BIN" ]; then
    # Show which model / port will be used
    if [ -n "$SQUISH_MODEL" ]; then
        print_info "squish model: ${CYAN}$SQUISH_MODEL${NC}"
    else
        print_info "squish model: ${GRAY}auto-detect${NC}"
    fi
    print_info "squish port:  ${CYAN}${SQUISH_PORT:-8000}${NC}"
    print_info "squish flags: ${GRAY}${SQUISH_FLAGS:-<none>}${NC}"

    # Check if a server is already listening on the port
    _port="${SQUISH_PORT:-8000}"
    if nc -z 127.0.0.1 "$_port" 2>/dev/null; then
        print_info "squish server: ${GREEN}already running on :$_port${NC}"
    else
        print_info "squish server: ${YELLOW}not running — squish will auto-start (first call ~20–90s)${NC}"
    fi
    echo ""

    # Prompt — send full diff, truncated only at MAX_DIFF_CHARS for token sanity
    PROMPT="Git commit message (max 50 chars, no quotes/formatting):
$diff"

    # Run squish with timeout and spinner
    print_step "Asking AI for commit message (Squish local LLM)..."
    # shellcheck disable=SC2086  # SQUISH_FLAGS intentionally word-splits for multi-flag support
    echo "$PROMPT" | timeout $TIMEOUT_SECONDS $SQUISH_BIN run $SQUISH_FLAGS --max-tokens 60 --temperature 0.2 2>/tmp/squish_stderr.txt | head -1 > /tmp/commit_msg.txt &
    LLM_PID=$!
    spinner $LLM_PID
    wait $LLM_PID
    exit_code=$?

    # ── Debug: result diagnostics ─────────────────────────────────────────
    commit_message=$(cat /tmp/commit_msg.txt 2>/dev/null)
    squish_stderr=$(cat /tmp/squish_stderr.txt 2>/dev/null)
    rm -f /tmp/commit_msg.txt /tmp/squish_stderr.txt

    print_info "squish exit code: ${CYAN}$exit_code${NC}"
    if [ -n "$commit_message" ]; then
        print_info "squish raw response: ${GREEN}\"$commit_message\"${NC}"
    else
        print_info "squish raw response: ${RED}<empty>${NC}"
    fi
    if [ -n "$squish_stderr" ]; then
        print_info "squish stderr: ${YELLOW}$(echo "$squish_stderr" | head -3)${NC}"
    fi
    echo ""

    # Check if timeout occurred or empty response
    if [ $exit_code -eq 124 ]; then
        print_warning "squish timed out after ${TIMEOUT_SECONDS}s. Using fallback message."
        commit_message="$fallback_message"
    elif [ -z "$commit_message" ]; then
        print_warning "squish returned empty response. Using fallback message."
        commit_message="$fallback_message"
    else
        print_success "squish responded successfully"
    fi
fi

# Clean up commit message formatting
commit_message=$(echo "$commit_message" | sed 's/#//g' | sed 's/```//g' | sed 's/Commit message://gi' | sed 's/\.//g' | sed 's/\"//g' | sed "s/'//g" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

# Truncate to max length at word boundary
if [ ${#commit_message} -gt $MAX_COMMIT_LENGTH ]; then
    commit_message=$(echo "$commit_message" | cut -c1-$MAX_COMMIT_LENGTH | sed 's/[[:space:]][^[:space:]]*$//')
fi

# Final fallback check
if [ -z "$commit_message" ] || [ "$commit_message" == "null" ]; then
    commit_message="$fallback_message"
fi

echo ""
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${WHITE}  📝 Commit Message${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ -n "$ticket" ]; then
    echo -e "  ${YELLOW}$ticket${NC} ${WHITE}$commit_message${NC}"
else
    echo -e "  ${WHITE}$commit_message${NC}"
fi
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Set the environment variables
export COMMIT_MESSAGE="$commit_message"
export TICKET="$ticket"

# Prepare and execute commit command, remove -S to commit without signing
print_step "Committing changes..."
if [ -z "$ticket" ]; then
	expect <<'EOF' > /dev/null 2>&1
spawn git commit -S -m "$env(COMMIT_MESSAGE)"
expect "Enter passphrase for \"/Users/wscholl/.ssh/id_ed25519\":"
send "$env(GIT_SSH_PASSPHRASE)\r"
expect eof
EOF
else
	expect <<'EOF' > /dev/null 2>&1
spawn git commit -S -m "$env(TICKET) $env(COMMIT_MESSAGE)"
expect "Enter passphrase for \"/Users/wscholl/.ssh/id_ed25519\":"
send "$env(GIT_SSH_PASSPHRASE)\r"
expect eof
EOF
fi
print_success "Committed successfully"

# Check if the branch exists on the remote
remote_branch=$(git ls-remote --heads origin $base_branch)

# Function: pull_push_after_failed_push - If push fails, attempt to pull and push again
pull_push_after_failed_push() {
	print_warning "Push failed. Attempting to pull and push again..."
	git fetch origin $base_branch > /dev/null 2>&1
	git pull > /dev/null 2>&1
	git push --force > /dev/null 2>&1
}

# Check if the branch exists on the remote
if [ -z "$remote_branch" ]; then
	# If the branch does not exist on the remote, create it
	print_step "Creating remote branch..."
	set -e
	git push --set-upstream origin $base_branch > /dev/null 2>&1

	# Check if the push was successful
	if [ $? -ne 0 ]; then
		pull_push_after_failed_push
	fi
	print_success "Branch created and pushed"
else
	# Branch exists on the remote, push changes
	print_step "Pushing to remote..."
	git fetch origin $base_branch > /dev/null 2>&1
	git pull > /dev/null 2>&1
	git push > /dev/null 2>&1

	# Check if the push wasn't successful
	if [ $? -ne 0 ]; then
		pull_push_after_failed_push
	fi
	print_success "Pushed successfully"
fi

# Animated success banner
show_pushed_banner() {
    echo ""
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    sleep 0.1
    echo -e "${GREEN}██████${WHITE}╗ ${GREEN}██${WHITE}╗   ${GREEN}██${WHITE}╗${GREEN}███████${WHITE}╗${GREEN}██${WHITE}╗  ${GREEN}██${WHITE}╗${GREEN}███████${WHITE}╗${GREEN}██████${WHITE}╗ ${GREEN}██${WHITE}╗${NC}"
    sleep 0.05
    echo -e "${GREEN}██${WHITE}╔══${GREEN}██${WHITE}╗${GREEN}██${WHITE}║   ${GREEN}██${WHITE}║${GREEN}██${WHITE}╔════╝${GREEN}██${WHITE}║  ${GREEN}██${WHITE}║${GREEN}██${WHITE}╔════╝${GREEN}██${WHITE}╔══${GREEN}██${WHITE}╗${GREEN}██${WHITE}║${NC}"
    sleep 0.05
    echo -e "${GREEN}██████${WHITE}╔╝${GREEN}██${WHITE}║   ${GREEN}██${WHITE}║${GREEN}███████${WHITE}╗${GREEN}███████${WHITE}║${GREEN}█████${WHITE}╗  ${GREEN}██${WHITE}║  ${GREEN}██${WHITE}║${GREEN}██${WHITE}║${NC}"
    sleep 0.05
    echo -e "${GREEN}██${WHITE}╔═══╝ ${GREEN}██${WHITE}║   ${GREEN}██${WHITE}║╚════${GREEN}██${WHITE}║${GREEN}██${WHITE}╔══${GREEN}██${WHITE}║${GREEN}██${WHITE}╔══╝  ${GREEN}██${WHITE}║  ${GREEN}██${WHITE}║╚═╝${NC}"
    sleep 0.05
    echo -e "${GREEN}██${WHITE}║     ╚${GREEN}██████${WHITE}╔╝${GREEN}███████${WHITE}║${GREEN}██${WHITE}║  ${GREEN}██${WHITE}║${GREEN}███████${WHITE}╗${GREEN}██████${WHITE}╔╝${GREEN}██${WHITE}╗${NC}"
    sleep 0.05
    echo -e "${WHITE}╚═╝      ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚═════╝ ╚═╝${NC}"
    echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${DIM}🚀 ${WHITE}Changes are now live on ${CYAN}$base_branch${NC}"
    echo ""
}

show_pushed_banner