#!/bin/bash
source ~/.bash_profile

# Configuration
MAX_DIFF_CHARS=300       # ~75 input tokens — halves prefill vs 600
TIMEOUT_SECONDS=120      # covers cold model.load_weights() (~90s) + inference
MAX_COMMIT_LENGTH=72     # Standard git commit length

# Squish model selection.
# qwen3:8b INT4 (~4.5 GB) — best quality on M3 16GB, ~22 tok/s generate.
# Override: SQUISH_MODEL=qwen3:4b cm  (faster, slightly lower quality)
SQUISH_MODEL="${SQUISH_MODEL:-1.5b}"

# Squish server port — must match the port squish is started with.
# CLI default is 11435; override with SQUISH_PORT env var.
SQUISH_PORT="${SQUISH_PORT:-11435}"
# test comment
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

# Escape a string for safe embedding in a JSON value.
# Uses only bash parameter expansion — zero subprocess forks.
_json_str() {
    local s="${1//\\/\\\\}"  # \ → \\
    local _q='"'
    s="${s//$_q/\\$_q}"      # " → \"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/\\r}"
    printf '%s' "$s"
}

# Snake spinner — loops forever until killed by the caller.
# Usage: snake_spinner [label]
#   Run in background (&), capture PID, kill after the task completes.
snake_spinner() {
    local label="${1:-Generating commit message}"
    local frames=('⣾' '⣽' '⣻' '⢿' '⡿' '⣟' '⣯' '⣷')
    local col_arr=("$CYAN" "$BLUE" "$PURPLE" "$CYAN" "$BLUE" "$PURPLE" "$CYAN" "$BLUE")
    local nf=${#frames[@]}
    local i=0 step=0

    while true; do
        local secs=$(( step / 10 ))
        local tenths=$(( step % 10 ))
        local c="${col_arr[$i]}"
        printf "\r${c}${frames[$i]}${NC} ${WHITE}${label}${NC}${GRAY}...${NC} ${DIM}(${secs}.${tenths}s)${NC}  "
        # read -t is a bash builtin — zero subprocess forks vs sleep
        read -t 0.1 </dev/null 2>/dev/null || true
        i=$(( (i + 1) % nf ))
        step=$(( step + 1 ))
    done
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
# squish is typically a zsh alias (not visible to bash scripts) — fall back to
# calling squish/cli.py directly with python3 if the command isn't on PATH.
# Also export SQUISH_MODELS_DIR so the CLI finds models in the squish repo.
export SQUISH_MODELS_DIR="${SQUISH_MODELS_DIR:-$HOME/squish/models}"_SQUISH_CLI="/Users/wscholl/squish/squish/cli.py"
SQUISH_BIN=$(command -v squish 2>/dev/null)
# command -v may return an alias definition string in some shells — treat that as not-found
if echo "$SQUISH_BIN" | grep -q '^alias '; then
    SQUISH_BIN=""
fi
if [ -z "$SQUISH_BIN" ] && [ -f "$_SQUISH_CLI" ]; then
    SQUISH_BIN="python3 $_SQUISH_CLI"
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

    # Check if a server is already listening on the port
    _port="${SQUISH_PORT:-8000}"
    if nc -z 127.0.0.1 "$_port" 2>/dev/null; then
        print_info "squish server: ${GREEN}already running on :$_port${NC}"
    else
        print_info "squish server: ${YELLOW}not running — starting it now…${NC}"
        # Draft model for speculative decoding — 1.5B drafts tokens, 7B verifies in
        # one forward pass. ~2-3x generation speedup; same output quality as 7B alone.
        _draft_model="${SQUISH_MODELS_DIR}/Qwen2.5-1.5B-Instruct-bf16-int8-bak"
        _draft_flag=""
        [ -d "$_draft_model" ] && _draft_flag="--draft-model $_draft_model"
        # Start the server in the background and wait for it
        $SQUISH_BIN serve ${SQUISH_MODEL:+--model $SQUISH_MODEL} --port "$_port" \
            --kv-cache-mode int8 \
            $_draft_flag \
            > /tmp/squish_serve.log 2>&1 &
        _serve_pid=$!
        # Run snake spinner in background while polling for server readiness
        snake_spinner "Starting squish server" &
        _snake_pid=$!
        _waited=0
        while [ $_waited -lt 90 ] && ! nc -z 127.0.0.1 "$_port" 2>/dev/null; do
            sleep 1
            _waited=$((_waited + 1))
        done
        kill "$_snake_pid" 2>/dev/null
        wait "$_snake_pid" 2>/dev/null
        printf "\r                                                                    \r"
        if ! nc -z 127.0.0.1 "$_port" 2>/dev/null; then
            print_warning "Server failed to start. Using fallback message."
            commit_message="$fallback_message"
        else
            print_success "Server ready (${_waited}s)"
        fi
    fi
    echo ""

    if [ -z "$commit_message" ]; then
        # Build a focused prompt — stat summary + truncated diff
        stat_summary=$(git diff --cached --stat | tail -1)
        changed_names=$(git diff --cached --name-only | head -10 | tr '\n' ' ')

        # Strip diff to +/- lines only (awk, no Python)
        stripped_diff=$(git diff --cached | awk '
            /^---/ || /^\+\+\+/                                        { next }
            /^diff / || /^index / || /^new file/ || /^deleted file/  { next }
            /^@@/ { sub(/^@@[^@]*@@ */, ""); print (length($0)>0 ? $0 : "~~"); next }
            /^\+/ || /^-/                                             { print }
        ' | head -c "$MAX_DIFF_CHARS")

        # Build JSON payload in pure bash — _json_str escapes all special chars
        # /no_think disables Qwen3 chain-of-thought so the model replies directly.
        _sys="Write a git commit message. Imperative mood, under 72 chars, no punctuation. Reply with ONLY the message."
        _usr="/no_think Files: ${changed_names}\nStat: ${stat_summary}\nDiff:\n${stripped_diff}"
        PAYLOAD='{"model":"squish","messages":[{"role":"system","content":"'"$(_json_str "$_sys")"'"},{"role":"user","content":"'"$(_json_str "$_usr")"'"}],"max_tokens":100,"temperature":0.2,"stream":false,"stop":["\n","\r"]}'

        # Run squish — curl in background, spinner inline in foreground (no subprocess)
        print_step "Asking AI for commit message (Squish local LLM)..."
        _port="${SQUISH_PORT:-11435}"
        curl -s --max-time $TIMEOUT_SECONDS \
            -X POST "http://127.0.0.1:${_port}/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${SQUISH_API_KEY:-squish}" \
            -d "$PAYLOAD" 2>/tmp/squish_stderr.txt \
            > /tmp/squish_response.txt &
        LLM_PID=$!
        # Inline spinner — runs in the main shell, no subprocess, no background PID
        _sp_frames=('⣾' '⣽' '⣻' '⢿' '⡿' '⣟' '⣯' '⣷')
        _sp_cols=("$CYAN" "$BLUE" "$PURPLE" "$CYAN" "$BLUE" "$PURPLE" "$CYAN" "$BLUE")
        _si=0; _step=0
        while kill -0 "$LLM_PID" 2>/dev/null; do
            _secs=$(( _step / 10 )); _tenths=$(( _step % 10 ))
            printf "\r${_sp_cols[$_si]}${_sp_frames[$_si]}${NC} ${WHITE}Generating commit message${NC}${GRAY}...${NC} ${DIM}(${_secs}.${_tenths}s)${NC}  "
            sleep 0.1
            _si=$(( (_si + 1) % 8 ))
            _step=$(( _step + 1 ))
        done
        wait $LLM_PID   # reap immediately — zombie cleared within one loop tick
        exit_code=$?
        printf "\r${GREEN}✓${NC} ${WHITE}Done!${NC}                                          \n"
        # step is already in tenths of a second — free decimal timing, no extra call
        _llm_secs=$(( _step / 10 )); _llm_tenths=$(( _step % 10 ))
        print_info "model response time: ${CYAN}${_llm_secs}.${_llm_tenths}s${NC}"

        # ── Debug: result diagnostics ─────────────────────────────────────────
        raw_response=$(cat /tmp/squish_response.txt 2>/dev/null)
        squish_stderr=$(cat /tmp/squish_stderr.txt 2>/dev/null)
        rm -f /tmp/squish_response.txt /tmp/squish_stderr.txt


        # Extract content from JSON robustly, then strip any CoT tags.
        # Prefer jq when available; keep a shell-only fallback.
        if command -v jq >/dev/null 2>&1; then
            commit_message=$(printf '%s' "$raw_response" | jq -r '.choices[0].message.content // .message.content // empty' 2>/dev/null)
        else
            commit_message=$(printf '%s' "$raw_response" | sed -n 's/.*"content":"\([^"]*\)".*/\1/p')
            commit_message=${commit_message//\\n/$'\n'}
            commit_message=${commit_message//\\r/$'\r'}
            commit_message=${commit_message//\\t/$'\t'}
            commit_message=${commit_message//\\\//\/}
            commit_message=${commit_message//\\\"/\"}
            commit_message=${commit_message//\\u003c/<}
            commit_message=${commit_message//\\u003e/>}
        fi

        # Remove <think> tags/content even when partial or multiline.
        commit_message=$(printf '%s' "$commit_message" | perl -0777 -pe 's#<think>.*?</think>\s*##gis; s#<think\b[^>]*>.*##gis; s#</think>##gis' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # If any think tag residue remains, force fallback by clearing it.
        if printf '%s' "$commit_message" | grep -qi '</\?think\b'; then
            commit_message=""
        fi

        print_info "squish exit code: ${CYAN}$exit_code${NC}"
        if [ -n "$commit_message" ]; then
            print_info "squish parsed message: ${GREEN}\"$commit_message\"${NC}"
        else
            print_info "squish parsed message: ${RED}<empty>${NC}"
            if [ -n "$raw_response" ]; then
                print_info "squish raw body: ${YELLOW}$(echo "$raw_response" | head -c 500)${NC}"
            else
                print_info "squish raw body: ${RED}<no response from server>${NC}"
            fi
        fi
        if [ -n "$squish_stderr" ]; then
            print_info "squish stderr: ${YELLOW}$(echo "$squish_stderr" | head -3)${NC}"
        fi
        echo ""

        # Check if timeout occurred or empty response
        if [ $exit_code -eq 28 ] || [ $exit_code -eq 124 ]; then
            print_warning "squish timed out after ${TIMEOUT_SECONDS}s (exit $exit_code). Using fallback message."
            commit_message="$fallback_message"
        elif [ -z "$commit_message" ]; then
            print_warning "squish returned empty response. Using fallback message."
            commit_message="$fallback_message"
        else
            print_success "squish responded successfully"
        fi
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