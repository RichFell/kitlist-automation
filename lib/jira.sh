# Jira Cloud REST helpers. Needs JIRA_SITE, JIRA_EMAIL, JIRA_TOKEN.

# jira_api METHOD PATH [JSON_BODY]
jira_api() {
  local method="$1" path="$2" data="${3:-}" out code
  out="$(printf 'user = "%s:%s"\n' "$JIRA_EMAIL" "$JIRA_TOKEN" | curl -sS -K - \
      -w '\n%{http_code}' -H 'Accept: application/json' -H 'Content-Type: application/json' \
      -X "$method" ${data:+--data-binary "$data"} "$JIRA_SITE$path")" || return 1
  code="${out##*$'\n'}"; out="${out%$'\n'*}"
  case "$code" in
    2??) printf '%s' "$out" ;;
    *) log "Jira $method $path returned HTTP $code: $(printf '%s' "$out" | head -c 300)"; return 1 ;;
  esac
}

jira_search_keys() {
  local body; body="$(jq -n --arg jql "$1" '{jql: $jql, maxResults: 20, fields: ["summary"]}')"
  jira_api POST /rest/api/3/search/jql "$body" | jq -r '.issues[].key'
}

# API v2 returns descriptions and comments as plain text, which is what Claude reads.
jira_issue() {
  jira_api GET "/rest/api/2/issue/$1?fields=summary,description,labels,issuetype,parent,issuelinks,comment,status"
}

# Keys of "is blocked by" tickets that aren't done yet, space separated.
open_blockers() {
  jira_issue "$1" | jq -r '[.fields.issuelinks[]?
    | select(.type.inward == "is blocked by" and .inwardIssue != null) | .inwardIssue
    | select(.fields.status.statusCategory.key != "done") | .key] | join(" ")'
}

jira_transition() {
  local key="$1" target="$2" id
  id="$(jira_api GET "/rest/api/2/issue/$key/transitions" \
        | jq -r --arg t "$target" '[.transitions[] | select(.to.name == $t)][0].id // empty')"
  [ -n "$id" ] || { log "$key: can't move to \"$target\" from its current status."; return 1; }
  jira_api POST "/rest/api/2/issue/$key/transitions" "$(jq -n --arg id "$id" '{transition: {id: $id}}')" >/dev/null
}

jira_comment()   { jira_api POST "/rest/api/2/issue/$1/comment" "$(jq -n --arg b "$2" '{body: $b}')" >/dev/null; }
jira_add_label() { jira_api PUT "/rest/api/2/issue/$1" "$(jq -n --arg l "$2" '{update: {labels: [{add: $l}]}}')" >/dev/null; }

# Ticket JSON on stdin -> markdown brief for Claude.
jira_ticket_markdown() {
  jq -r --arg site "$JIRA_SITE" '
    "# \(.key): \(.fields.summary)\n\n" +
    "- Type: \(.fields.issuetype.name)\n" +
    "- Labels: \(.fields.labels | join(", "))\n" +
    "- Parent: \(if .fields.parent then "\(.fields.parent.key) (\(.fields.parent.fields.summary))" else "none" end)\n" +
    "- Jira: \($site)/browse/\(.key)\n\n" +
    "## Description\n\n\(.fields.description // "(no description)")\n\n" +
    "## Comments\n\n" +
    ([.fields.comment.comments[]? | "**\(.author.displayName)** (\(.created[0:10])):\n\(.body)"]
      | if length == 0 then "(none)" else join("\n\n") end)'
}

# Ticket JSON as $1 -> "## Related tickets" section with the parent's and each
# linked ticket's description, so Claude doesn't stop because it can't open them.
jira_related_markdown() {
  local keys key rel
  keys="$(printf '%s' "$1" | jq -r '
    (if .fields.parent then "\(.fields.parent.key)\tparent" else empty end),
    (.fields.issuelinks[]? | if .inwardIssue then "\(.inwardIssue.key)\t\(.type.inward)"
                             else "\(.outwardIssue.key)\t\(.type.outward)" end)')"
  [ -n "$keys" ] || return 0
  printf '\n\n## Related tickets\n'
  printf '%s\n' "$keys" | while IFS="$(printf '\t')" read -r key rel; do
    valid_key "$key" || continue
    jira_api GET "/rest/api/2/issue/$key?fields=summary,status,description" | jq -r --arg rel "$rel" '
      "\n### \(.key) (\($rel), \(.fields.status.name)): \(.fields.summary)\n\n" +
      ((.fields.description // "(no description)") as $d
        | if ($d | length) > 3000 then $d[0:3000] + "\n\n(truncated)" else $d end)' || true
  done
}
