#!/bin/bash
# ticket-runner.sh: picks up Kitlist Jira tickets in "Ready for Claude", has
# Claude Code implement and self-review each one in a fresh worktree, then
# pushes the branch, opens a GitHub PR and moves the ticket to "In Review".
#
#   ticket-runner.sh                     normal run (what launchd starts hourly)
#   ticket-runner.sh --ticket SCRUM-12   work this ticket now, whatever its column
#   ticket-runner.sh --dry-run           show what would be picked up; change nothing
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/config.sh"
for f in common jira devices pipeline; do source "$HERE/lib/$f.sh"; done

ONLY_TICKET=""; DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --ticket) ONLY_TICKET="${2:?--ticket needs a ticket key}"; shift 2
      valid_key "$ONLY_TICKET" || { echo "Not a Jira key: $ONLY_TICKET" >&2; exit 2; } ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$STATE_DIR/runs" "$STATE_DIR/worktrees" "$STATE_DIR/repos" "$STATE_DIR/logs"
LOG_FILE="$STATE_DIR/logs/runner.log"

acquire_lock || exit 0
trap release_lock EXIT
preflight || exit 1
JIRA_TOKEN="$(security find-generic-password -a "$JIRA_EMAIL" -s "$JIRA_TOKEN_KEYCHAIN_SERVICE" -w 2>/dev/null)" ||
  die "No Jira API token in the Keychain. Run install.sh."

if [ -n "$ONLY_TICKET" ]; then
  tickets="$ONLY_TICKET"
else
  jql="project = $JIRA_PROJECT AND status = \"$PICKUP_STATUS\" AND (labels IS EMPTY OR labels != $BLOCKED_LABEL) ORDER BY Rank ASC"
  tickets="$(jira_search_keys "$jql")" || die "Jira search failed. Does the board have a \"$PICKUP_STATUS\" column?"
fi
[ -n "$tickets" ] || { log "Nothing in \"$PICKUP_STATUS\"."; exit 0; }

taken=0
for key in $tickets; do
  [ "$taken" -lt "$MAX_TICKETS_PER_RUN" ] || break
  valid_key "$key" || { log "Skipping \"$key\": not a Jira key like $JIRA_PROJECT-12."; continue; }
  blockers="$(open_blockers "$key" || true)"
  if [ -n "$blockers" ]; then log "$key is waiting on unfinished tickets ($blockers); skipping."; continue; fi
  taken=$((taken + 1))
  if [ "$DRY_RUN" = 1 ]; then log "[dry run] would work $key"; continue; fi
  ( process_ticket "$key" ) || true
done
