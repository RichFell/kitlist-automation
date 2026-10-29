# One ticket, start to finish. Runs in a subshell so profile settings don't leak.

COMMON_ALLOW=(
  Read Write Edit Glob Grep
  "Bash(git status*)" "Bash(git diff*)" "Bash(git log*)" "Bash(git show*)"
  "Bash(git ls-files*)" "Bash(git ls-tree*)" "Bash(git grep*)" "Bash(which *)"
  "Bash(git add *)" "Bash(git commit *)" "Bash(git restore *)" "Bash(git rm *)" "Bash(git mv *)"
  "Bash(ls)" "Bash(ls *)" "Bash(cat *)" "Bash(head *)" "Bash(tail *)" "Bash(wc *)" "Bash(grep *)"
  "Bash(mkdir *)" "Bash(cp *)" "Bash(mv *)" "Bash(jq *)" "Bash(sips *)" "Bash(sleep *)"
  "mcp__figma" "mcp__Figma" "mcp__claude_ai_Figma" Agent Task
)
COMMON_DENY=(
  "Bash(git push*)" "Bash(git checkout*)" "Bash(git switch*)" "Bash(git reset --hard*)"
  "Bash(git rebase*)" "Bash(git branch -D*)" "Bash(git worktree*)" "Bash(git remote*)"
  "Bash(gh *)" "Bash(curl *)" "Bash(wget *)" "Bash(rm -rf*)" "Bash(sudo *)" "Bash(security *)"
  # Personal files and credentials. Builds use DerivedData under STATE_DIR, so
  # nothing a ticket needs lives in these folders.
  "Read(~/Library/**)" "Read(~/Documents/**)" "Read(~/Desktop/**)" "Read(~/Downloads/**)"
  "Read(~/.ssh/**)" "Read(~/.aws/**)" "Read(~/.gnupg/**)" "Read(~/.config/**)" "Read(~/.netrc)"
  "Read(~/.zsh_history)" "Read(~/.bash_history)"
  "Read(~/.kitlist-automation/settings/**)" "Read(~/.kitlist-automation/logs/**)"
)

fail_ticket() {
  local key="$1" reason="$2"
  log "$key: blocked: $reason"
  jira_transition "$key" "$FALLBACK_STATUS" || true
  jira_add_label "$key" "$BLOCKED_LABEL" || true
  jira_comment "$key" "Claude couldn't finish this ticket: $reason

Logs on the Mac: ${RUN_DIR:-$LOG_FILE}

To retry, fix the ticket or the cause, remove the $BLOCKED_LABEL label, and move the card back to $PICKUP_STATUS." || true
  return 1
}

ensure_repo() {
  REPO="$STATE_DIR/repos/${GH_REPO#*/}"
  if [ ! -d "$REPO/.git" ]; then
    gh repo clone "$GH_REPO" "$REPO" -- --quiet >>"$LOG_FILE" 2>&1 || return 1
  fi
  git -C "$REPO" fetch origin --prune --quiet || return 1
  if [ -z "$BASE_BRANCH" ]; then
    BASE_BRANCH="$(gh repo view "$GH_REPO" --json defaultBranchRef -q .defaultBranchRef.name)" || return 1
  fi
  git -C "$REPO" rev-parse --verify --quiet "origin/$BASE_BRANCH" >/dev/null ||
    { log "$KEY: $GH_REPO has no $BASE_BRANCH branch on GitHub"; BASE_MISSING=1; return 1; }
}

# Copies supabase/schemas from the backend's $BACKEND_SCHEMA_BRANCH into
# RUN_DIR/backend-schema, so app and ServicesFactory tickets use the real table,
# column and function names. A failure only logs a warning.
copy_backend_schema() {
  local repo="$STATE_DIR/repos/${BACKEND_REPO#*/}"
  [ "$PROFILE" = backend ] && return 0
  if [ ! -d "$repo/.git" ]; then
    gh repo clone "$BACKEND_REPO" "$repo" -- --quiet >>"$LOG_FILE" 2>&1 ||
      { log "$KEY: warning: couldn't clone $BACKEND_REPO, so the run has no backend schema"; return 0; }
  fi
  mkdir -p "$RUN_DIR/backend-schema"
  { git -C "$repo" fetch origin --prune --quiet &&
    git -C "$repo" archive "origin/$BACKEND_SCHEMA_BRANCH" supabase/schemas |
      tar -x -C "$RUN_DIR/backend-schema" --strip-components 2; } ||
    log "$KEY: warning: couldn't copy the backend schema from $BACKEND_REPO"
}

# The settings file lives outside every directory Claude can write to, and is
# rewritten before each phase, so one phase can't widen the next one's permissions.
# "//" makes a rule path absolute. .claude/ is denied too: the review phase would
# otherwise load project settings or hooks the implement phase wrote. The runner's
# own files are denied because profiles allow its scripts/ helpers to run, and
# ~/.claude because a later run would load memory or settings written there.
# Auto memory is off for the same reason: notes a run leaves for itself belong in
# the profile, where a human reviews them.
write_settings() {
  local allow deny protect=() p
  for p in "$SETTINGS_FILE" "$WT/.claude/**" "$RUN_DIR/.claude/**" "$HERE/**" "$HOME/.claude/**"; do
    protect+=("Edit(/$p)" "Write(/$p)")
  done
  allow="$(json_array "${COMMON_ALLOW[@]}" ${PROFILE_ALLOW[@]+"${PROFILE_ALLOW[@]}"})"
  deny="$(json_array "${COMMON_DENY[@]}" ${PROFILE_DENY[@]+"${PROFILE_DENY[@]}"} "${protect[@]}")"
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  jq -n --argjson a "$allow" --argjson d "$deny" \
    '{autoMemoryEnabled: false, permissions: {allow: $a, deny: $d}}' > "$SETTINGS_FILE"
}

# run_claude PHASE PROMPT_FILE MAX_TURNS [MODEL]
run_claude() {
  local phase="$1" prompt rc
  # PROFILE goes first so placeholders inside the profile text are filled in too.
  prompt="$(render_template "$2" PROFILE "$(cat "$HERE/profiles/$PROFILE.md")" KEY "$KEY" \
            RUN_DIR "$RUN_DIR" BASE_BRANCH "$BASE_BRANCH" BRANCH "$BRANCH" TARGETS "$TARGETS" \
            DERIVED_DATA "${DERIVED_DATA:-}" SCRIPTS "$HERE/scripts")"
  write_settings
  local args=(-p "$prompt" --settings "$SETTINGS_FILE" --permission-mode acceptEdits
              --add-dir "$RUN_DIR" --output-format json --max-turns "$3")
  [ -n "${4:-}" ] && args+=(--model "$4")
  [ -n "$CLAUDE_EFFORT" ] && args+=(--effort "$CLAUDE_EFFORT")
  # Only the large app repos are worth surveying with Explore subagents.
  local tools="$CLAUDE_TOOLS"
  [ "$phase" = implement ] && [ "${USE_SUBAGENTS:-0}" = 1 ] && tools="$tools,Agent"
  [ -n "$tools" ] && args+=(--tools "$tools")
  # The owner's skills and MCP servers add ~15k tokens to every turn. Drop the
  # skills always, and the MCP servers unless the profile allows the Figma connector
  # and the ticket brief actually links a Figma design.
  args+=(--disable-slash-commands)
  if [ "${USE_FIGMA:-0}" = 1 ] && grep -q 'figma\.com/' "$RUN_DIR/ticket.md" 2>/dev/null; then
    log "$KEY: $phase keeps MCP servers for the Figma link"
  else
    args+=(--strict-mcp-config)
  fi
  log "$KEY: $phase started"
  # KITLIST_* tell the profile's scripts/ helpers where the run's files are.
  # _FORCE drops the Agent tool's own model argument, which otherwise beats the
  # env var (SCRUM-35's Explore ran on haiku because the call asked for it).
  ( cd "$WT" && export CLAUDE_CODE_SUBAGENT_MODEL="${CLAUDE_SUBAGENT_MODEL:-}" CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1 &&
    { [ -n "$CLAUDE_SUBAGENT_MODEL" ] || unset CLAUDE_CODE_SUBAGENT_MODEL CLAUDE_CODE_SUBAGENT_MODEL_FORCE; } &&
    export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 KITLIST_RUN_DIR="$RUN_DIR" KITLIST_DERIVED_DATA="${DERIVED_DATA:-}" &&
    caffeinate -i claude "${args[@]}" ) >"$RUN_DIR/$phase.json" 2>"$RUN_DIR/$phase.err"
  rc=$?
  if [ $rc -ne 0 ] || [ "$(jq -r '.is_error // false' "$RUN_DIR/$phase.json" 2>/dev/null)" != "false" ]; then
    log "$KEY: $phase failed (exit $rc, $(jq -r '.subtype // "no result"' "$RUN_DIR/$phase.json" 2>/dev/null))"
    return 1
  fi
  log "$KEY: $phase finished: $(phase_calls "$phase"), $(with_commas "$(phase_tokens "$phase")") new tokens" \
      "+ $(with_commas "$(phase_tokens "$phase" cached)") cache reads, \$$(jq -r '.total_cost_usd // 0 | . * 100 | round / 100' "$RUN_DIR/$phase.json")"
}

# "N model calls, M tool calls" for a phase, counted from its session transcript.
# The result's num_turns counts tool results, not model calls, so it reads far
# higher than what --max-turns limits.
phase_calls() {
  local sid t
  sid="$(jq -r '.session_id // ""' "$RUN_DIR/$1.json" 2>/dev/null)"
  t="$HOME/.claude/projects/$(printf '%s' "$WT" | sed 's/[^A-Za-z0-9]/-/g')/$sid.jsonl"
  if [ -z "$sid" ] || [ ! -f "$t" ]; then
    echo "$(jq -r '.num_turns // "?"' "$RUN_DIR/$1.json") turns"; return
  fi
  jq -rs '[.[] | select(.type == "assistant")] as $a
    | "\($a | map(.message.id) | unique | length) model calls, \([$a[].message.content[]? | select(.type == "tool_use")] | length) tool calls"' "$t"
}

# Tokens a phase used. Default: fresh input, cache writes and output. "cached": cache
# reads, which re-read the whole context on every model call and cost about a tenth.
phase_tokens() {
  if [ "${2:-}" = cached ]; then
    jq -r '.usage.cache_read_input_tokens // 0' "$RUN_DIR/$1.json" 2>/dev/null || echo 0
  else
    jq -r '.usage | (.input_tokens // 0) + (.cache_creation_input_tokens // 0)
                  + (.output_tokens // 0)' "$RUN_DIR/$1.json" 2>/dev/null || echo 0
  fi
}

with_commas() { printf '%s' "$1" | rev | sed 's/[0-9]\{3\}/&,/g' | rev | sed 's/^,//'; }

# Fails the ticket unless Claude wrote status.json with status "done".
require_done() {
  local status reason
  status="$(jq -r '.status // "missing"' "$RUN_DIR/status.json" 2>/dev/null || echo missing)"
  reason="$(jq -r '.reason // ""' "$RUN_DIR/status.json" 2>/dev/null || true)"
  case "$status" in
    done) rm -f "$RUN_DIR/status.json"; return 0 ;;
    blocked) fail_ticket "$KEY" "${reason:-Claude stopped without giving a reason.} (during $1)" ;;
    *) fail_ticket "$KEY" "the $1 step ended without reporting a result." ;;
  esac
}

# Pushes screenshots to the repo's pr-assets branch and appends them to the PR body.
publish_screenshots() {
  local shots=() f n aw
  for f in "$RUN_DIR"/screenshots/*.png "$RUN_DIR"/screenshots/*.jpg; do
    [ -f "$f" ] || continue
    n="$(basename "$f" | tr ' ' '-')"; [ "$n" = "$(basename "$f")" ] || mv "$f" "$RUN_DIR/screenshots/$n"
    shots+=("$RUN_DIR/screenshots/$n")
  done
  [ ${#shots[@]} -gt 0 ] || return 0
  aw="$STATE_DIR/worktrees/${GH_REPO#*/}/assets-$KEY"
  rm -rf "$aw"; git -C "$REPO" worktree prune
  if git -C "$REPO" ls-remote --exit-code --heads origin pr-assets >/dev/null 2>&1; then
    git -C "$REPO" fetch --quiet origin pr-assets &&
      git -C "$REPO" worktree add --quiet -B pr-assets "$aw" origin/pr-assets || return 1
  else
    git -C "$REPO" worktree add --quiet --detach "$aw" || return 1
    ( cd "$aw" && git checkout --quiet --orphan pr-assets && git rm -rfq . &&
      printf '# PR screenshots\n\nImages referenced from pull requests. Safe to prune.\n' > README.md ) || return 1
  fi
  mkdir -p "$aw/$KEY" && cp "${shots[@]}" "$aw/$KEY/"
  ( cd "$aw" && git add -A && git commit --quiet -m "Screenshots for $KEY" && git push --quiet origin pr-assets ) || return 1
  git -C "$REPO" worktree remove --force "$aw"
  { printf '\n## Screenshots\n\n'
    for f in "${shots[@]}"; do
      n="$(basename "$f")"
      printf '**%s**\n\n<img src="https://github.com/%s/blob/pr-assets/%s/%s?raw=true" width="300">\n\n' \
        "${n%.*}" "$GH_REPO" "$KEY" "$n"
    done; } >> "$BODY"
}

process_ticket() {
  KEY="$1"
  local issue labels summary existing ahead leftovers pr_url
  valid_key "$KEY" || { log "Refusing \"$KEY\": not a Jira key."; return 1; }
  issue="$(jira_issue "$KEY")" || { log "$KEY: couldn't read the ticket"; return 1; }
  summary="$(printf '%s' "$issue" | jq -r .fields.summary)"
  labels="$(printf '%s' "$issue" | jq -r '.fields.labels[]')"
  issuetype="$(printf '%s' "$issue" | jq -r '.fields.issuetype.name // ""')"
  TARGETS="$(targets_for_labels "$labels")"
  PROFILE="$(profile_for_targets "$TARGETS")" ||
    { fail_ticket "$KEY" "its platform labels must all belong to one repo: ios (kitlist-ios), android (kitlist-android), backend (kitlist-backend), or servicesfactory (kitlist-ios-services). Split it into one ticket per repo."; return 1; }
  source "$HERE/profiles/$PROFILE.sh"

  RUN_ID="$KEY-$(date +%Y%m%d-%H%M%S)"
  RUN_DIR="$STATE_DIR/runs/$RUN_ID"
  SETTINGS_FILE="$STATE_DIR/settings/$RUN_ID.json"
  mkdir -p "$RUN_DIR/screenshots"
  printf '%s' "$issue" > "$RUN_DIR/ticket.json"
  { printf '%s' "$issue" | jira_ticket_markdown; jira_related_markdown "$issue"; } > "$RUN_DIR/ticket.md"
  log "$KEY: starting ($TARGETS) $summary"

  BASE_MISSING=0
  if ! ensure_repo; then
    if [ "$BASE_MISSING" = 1 ]; then
      fail_ticket "$KEY" "$GH_REPO has no $BASE_BRANCH branch on GitHub to base the PR on. Push one, then retry."
    else
      fail_ticket "$KEY" "couldn't clone or fetch $GH_REPO. If the GitHub repo doesn't exist yet, create it (see the README)."
    fi
    return 1
  fi

  BRANCH="$(branch_prefix "$issuetype")/$KEY"
  existing="$(gh pr list --repo "$GH_REPO" --head "$BRANCH" --state open --json url -q '.[0].url' 2>/dev/null || true)"
  if [ -n "$existing" ]; then
    log "$KEY: already has an open PR ($existing); moving it to $REVIEW_STATUS"
    jira_transition "$KEY" "$REVIEW_STATUS" || true
    return 0
  fi
  # A branch with no open PR may still hold someone's work (closed PR, manual
  # commits). Never reset or overwrite it; let a human decide.
  if git -C "$REPO" ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
    fail_ticket "$KEY" "branch $BRANCH already exists on GitHub without an open PR. Delete it or open a PR from it, then retry."
    return 1
  fi

  jira_transition "$KEY" "$WORKING_STATUS" || true
  WT="$STATE_DIR/worktrees/${GH_REPO#*/}/$KEY"
  if [ -d "$WT" ]; then git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"; fi
  git -C "$REPO" worktree prune
  git -C "$REPO" worktree add --quiet -B "$BRANCH" "$WT" "origin/$BASE_BRANCH" ||
    { fail_ticket "$KEY" "couldn't create a worktree from origin/$BASE_BRANCH."; return 1; }
  prepare_worktree
  copy_backend_schema

  trap device_down EXIT
  device_up || { fail_ticket "$KEY" "a simulator or emulator for $TARGETS didn't start (see the runner log)."; return 1; }

  run_claude implement "$HERE/prompts/implement.md" "$MAX_TURNS_IMPLEMENT" "$CLAUDE_MODEL_IMPLEMENT" ||
    { fail_ticket "$KEY" "the implementation step errored or ran out of turns."; return 1; }
  require_done implementation || return 1
  ahead="$(git -C "$WT" rev-list --count "origin/$BASE_BRANCH..HEAD")"
  [ "$ahead" -gt 0 ] || { fail_ticket "$KEY" "Claude finished without committing any changes."; return 1; }

  run_claude review "$HERE/prompts/review.md" "$MAX_TURNS_REVIEW" "$CLAUDE_MODEL_REVIEW" ||
    { fail_ticket "$KEY" "the self-review step errored or ran out of turns."; return 1; }
  require_done self-review || return 1
  device_down; trap - EXIT

  [ -s "$RUN_DIR/pr-body.md" ] || printf '## Summary\n\n%s\n' "$summary" > "$RUN_DIR/pr-body.md"
  BODY="$RUN_DIR/final-body.md"
  cp "$RUN_DIR/pr-body.md" "$BODY"
  leftovers="$(git -C "$WT" status --porcelain)"
  if [ -n "$leftovers" ]; then
    printf '\n> **Note:** these uncommitted files were left out of the PR:\n> ```\n%s\n> ```\n' \
      "$(printf '%s\n' "$leftovers" | sed 's/^/> /')" >> "$BODY"
  fi
  publish_screenshots ||
    printf '\n> Screenshots couldn'"'"'t be uploaded. They are on the Mac in %s/screenshots.\n' "$RUN_DIR" >> "$BODY"
  local impl_tokens review_tokens cached tokens
  impl_tokens="$(phase_tokens implement)"; review_tokens="$(phase_tokens review)"
  cached=$(( $(phase_tokens implement cached) + $(phase_tokens review cached) ))
  tokens="$(with_commas $((impl_tokens + review_tokens))) new tokens (implement $(with_commas "$impl_tokens"), review $(with_commas "$review_tokens")) + $(with_commas "$cached") cache reads"
  printf '\n---\nJira: [%s](%s/browse/%s) · Implemented and self-reviewed by Claude Code · %s\n' \
    "$KEY" "$JIRA_SITE" "$KEY" "$tokens" >> "$BODY"

  git -C "$WT" push --quiet -u origin "$BRANCH" >>"$LOG_FILE" 2>&1 ||
    { fail_ticket "$KEY" "pushing $BRANCH to GitHub failed."; return 1; }
  pr_url="$(gh pr create --repo "$GH_REPO" --base "$BASE_BRANCH" --head "$BRANCH" \
              --title "[$KEY] $summary" --body-file "$BODY" 2>>"$LOG_FILE")" ||
    { fail_ticket "$KEY" "the branch was pushed but opening the PR failed."; return 1; }

  jira_transition "$KEY" "$REVIEW_STATUS" || true
  jira_comment "$KEY" "Pull request ready for review: $pr_url
Tokens used: $tokens" || true
  git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || true
  log "$KEY: PR opened $pr_url, $tokens"
}
