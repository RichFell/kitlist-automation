#!/bin/bash
# Installs (or updates) the hourly Kitlist ticket runner on this Mac.
#   ./install.sh               install or update; asks for the Jira token the first time
#   ./install.sh --reset-token store a new Jira API token
#   ./install.sh --uninstall   stop the hourly job (keeps logs and clones)
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SRC/config.sh"
APP_DIR="$STATE_DIR/app"
LABEL="com.richfell.kitlist-ticket-runner"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
DOMAIN="gui/$(id -u)"

if [ "${1:-}" = "--uninstall" ]; then
  launchctl bootout "$DOMAIN" "$PLIST" 2>/dev/null || true
  rm -f "$PLIST"
  echo "Stopped the hourly runner. Logs, clones and runs are still in $STATE_DIR."
  exit 0
fi

missing=""
for c in git gh jq claude; do command -v "$c" >/dev/null 2>&1 || missing="$missing $c"; done
if [ -n "$missing" ]; then
  echo "Missing:$missing"
  echo "  gh, jq: brew install gh jq"
  echo "  claude: install Claude Code and sign in once by running 'claude'"
  exit 1
fi
gh auth status >/dev/null 2>&1 || { echo "Sign in to GitHub first: gh auth login"; exit 1; }

if [ "${1:-}" = "--reset-token" ] ||
   ! security find-generic-password -a "$JIRA_EMAIL" -s "$JIRA_TOKEN_KEYCHAIN_SERVICE" >/dev/null 2>&1; then
  echo "Create a Jira API token at https://id.atlassian.com/manage-profile/security/api-tokens"
  # Read it ourselves: the Keychain's own password prompt cuts input off at 128
  # characters, and Atlassian tokens are longer.
  read -r -s -p "Paste the token (it won't be shown) and press Return: " tok; echo
  [ ${#tok} -ge 100 ] || { echo "That's only ${#tok} characters; Atlassian tokens are about 190. Try again."; exit 1; }
  security add-generic-password -U -a "$JIRA_EMAIL" -s "$JIRA_TOKEN_KEYCHAIN_SERVICE" -w "$tok"
  unset tok
  if printf 'user = "%s:%s"\n' "$JIRA_EMAIL" \
       "$(security find-generic-password -a "$JIRA_EMAIL" -s "$JIRA_TOKEN_KEYCHAIN_SERVICE" -w)" |
     curl -sf -K - "$JIRA_SITE/rest/api/3/myself" >/dev/null; then
    echo "Jira accepted the token."
  else
    echo "Jira rejected the token. Check JIRA_EMAIL in config.sh, then run ./install.sh --reset-token."
    exit 1
  fi
fi

# launchd can't read ~/Documents, so the runner executes from a copy in $APP_DIR.
mkdir -p "$APP_DIR" "$STATE_DIR/logs" "$HOME/Library/LaunchAgents"
rsync -a --delete --exclude install.sh --exclude README.md --exclude .DS_Store --exclude _to_delete "$SRC/" "$APP_DIR/"
chmod +x "$APP_DIR/ticket-runner.sh"
sed -e "s|__LABEL__|$LABEL|" -e "s|__RUNNER__|$APP_DIR/ticket-runner.sh|" -e "s|__LOGDIR__|$STATE_DIR/logs|g" \
  "$SRC/launchd/runner.plist.template" > "$PLIST"
launchctl bootout "$DOMAIN" "$PLIST" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"

echo "Installed. The runner checks Jira every hour while this Mac is awake."
echo "  Check the board now:   $APP_DIR/ticket-runner.sh --dry-run"
echo "  Work a ticket now:     $APP_DIR/ticket-runner.sh --ticket SCRUM-12"
echo "  Watch the log:         tail -f $STATE_DIR/logs/runner.log"
