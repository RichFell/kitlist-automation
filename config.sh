# Kitlist ticket runner configuration. Sourced by ticket-runner.sh and install.sh.
# After editing, re-run ./install.sh so the installed copy picks up the change.

JIRA_SITE="https://richfellure.atlassian.net"
JIRA_EMAIL="rich.fellure@gmail.com"
JIRA_PROJECT="SCRUM"
JIRA_TOKEN_KEYCHAIN_SERVICE="listapp-jira-token"

# Board flow. Drag a card into PICKUP_STATUS to hand it to Claude.
PICKUP_STATUS="Ready for Claude"
WORKING_STATUS="In Progress"
REVIEW_STATUS="In Review"
FALLBACK_STATUS="To Do"
BLOCKED_LABEL="claude-blocked"
READY_LABEL="ai-ready"         # cards need this label to be picked up; empty = no gate. --ticket ignores it.

# Limits per run. launchd starts a run every hour while the Mac is awake.
MAX_TICKETS_PER_RUN=1
MAX_TURNS_IMPLEMENT=80          # a ticket that needs more is usually too big; split it
MAX_TURNS_REVIEW=80
CLAUDE_MODEL_IMPLEMENT=""      # empty = Claude Code's default model
CLAUDE_MODEL_REVIEW="sonnet"   # the review reads an existing diff, so a cheaper model is enough
CLAUDE_SUBAGENT_MODEL="sonnet" # Explore subagents survey code in their own context
CLAUDE_EFFORT=""               # low|medium|high|xhigh|max; empty = Claude Code's default
# Built-in tools each phase loads. Every tool's schema is re-read on every turn, so
# keep this to what the phases use. Profiles with USE_SUBAGENTS=1 add Agent to implement.
CLAUDE_TOOLS="Bash,Read,Write,Edit,Glob,Grep"

# Other repos' tickets get a copy of the backend schema, the contract between the apps.
BACKEND_REPO="RichFell/kitlist-backend"
BACKEND_SCHEMA_BRANCH="stage"

# Where the runner keeps its own clones, worktrees, run logs and installed copy.
STATE_DIR="$HOME/.kitlist-automation"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
if [ -z "${JAVA_HOME:-}" ] && [ -d "/Applications/Android Studio.app/Contents/jbr/Contents/Home" ]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:/usr/bin:/bin:/usr/sbin:/sbin"
