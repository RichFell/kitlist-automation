#!/usr/bin/env bash
#
# jira-to-md.sh — fetch a Jira Cloud issue and save it as a Markdown file.
#
# Usage:
#   jira-to-md.sh [-o OUTPUT] [-f] ISSUE-KEY
#
#   -o OUTPUT  Output file or directory (default: ./ISSUE-KEY.md)
#   -f         Overwrite the output file if it already exists
#   -h         Show help
#
# Uses the ticket runner's Jira settings: JIRA_SITE and JIRA_EMAIL from
# config.sh, and the API token that ./install.sh stored in the Keychain.
#
# Requires: curl, jq, security

set -euo pipefail

usage() { sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'; }
die()   { echo "Error: $*" >&2; exit 1; }

output=""
force=0
while getopts ":o:fh" opt; do
  case "$opt" in
    o) output="$OPTARG" ;;
    f) force=1 ;;
    h) usage; exit 0 ;;
    :) die "-$OPTARG requires an argument" ;;
    *) usage >&2; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

[[ $# -eq 1 ]] || { usage >&2; exit 1; }

# Accept a bare key ("abc-123") or a browse URL (".../browse/ABC-123").
key="$(basename "$1" | tr '[:lower:]' '[:upper:]')"
[[ "$key" =~ ^[A-Z][A-Z0-9_]*-[0-9]+$ ]] || die "'$1' doesn't look like a Jira issue key (e.g. ABC-123)"

for cmd in curl jq security; do
  command -v "$cmd" >/dev/null || die "'$cmd' is required but not installed"
done

# config.sh sits one level up, both here and in the installed copy.
config="$(cd "$(dirname "$0")/.." && pwd)/config.sh"
[[ -f "$config" ]] || die "can't find $config"
# shellcheck source=../config.sh
source "$config"
JIRA_BASE_URL="$JIRA_SITE"
JIRA_API_TOKEN="$(security find-generic-password -a "$JIRA_EMAIL" -s "$JIRA_TOKEN_KEYCHAIN_SERVICE" -w 2>/dev/null)" ||
  die "no Jira token in the Keychain for $JIRA_EMAIL (run ./install.sh --reset-token)"
base="${JIRA_BASE_URL%/}"

if [[ -z "$output" ]]; then
  output="./$key.md"
elif [[ -d "$output" ]]; then
  output="${output%/}/$key.md"
fi
[[ $force -eq 1 || ! -e "$output" ]] || die "$output already exists (use -f to overwrite)"

# --- Fetch ------------------------------------------------------------------
fields="summary,status,issuetype,priority,assignee,reporter,created,updated,duedate,labels,components,fixVersions,parent,description,comment,attachment,issuelinks,subtasks"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Credentials go in on stdin so the token never shows up in `ps`.
http_code="$(printf 'user = "%s:%s"\n' "$JIRA_EMAIL" "$JIRA_API_TOKEN" | curl -sS -K - \
  -o "$tmp" -w '%{http_code}' \
  -H 'Accept: application/json' \
  "$base/rest/api/3/issue/$key?fields=$fields")" || die "request to $base failed"

case "$http_code" in
  200) ;;
  401) die "authentication failed (check JIRA_EMAIL in config.sh, or run ./install.sh --reset-token)" ;;
  403) die "you don't have permission to view $key" ;;
  404) die "issue $key not found" ;;
  *)   die "Jira returned HTTP $http_code: $(jq -r '(.errorMessages // []) | join("; ")' "$tmp" 2>/dev/null || cat "$tmp")" ;;
esac

# --- Convert ----------------------------------------------------------------
# Jira's v3 API returns rich text as Atlassian Document Format (ADF) JSON;
# the jq below renders ADF to Markdown and assembles the full document.
markdown="$(jq -r --arg base "$base" '
  def pad($n): [range($n)] | map("    ") | join("");

  def md($d):
    def kids($d): (.content // []) | map(md($d)) | join("");
    # List item: inline content on the bullet line, nested lists indented below it.
    def li($d; $prefix):
      pad($d) + $prefix
      + ([.content[] | select(.type != "bulletList" and .type != "orderedList" and .type != "taskList") | md($d) | sub("\\n+$"; "")] | join(" "))
      + "\n"
      + ([.content[] | select(.type == "bulletList" or .type == "orderedList" or .type == "taskList") | md($d + 1)] | join(""));
    if .type == "text" then
      .text as $t
      | reduce (.marks // [])[] as $m ($t;
          if   $m.type == "code"   then "`" + . + "`"
          elif $m.type == "strong" then "**" + . + "**"
          elif $m.type == "em"     then "*" + . + "*"
          elif $m.type == "strike" then "~~" + . + "~~"
          elif $m.type == "link"   then "[" + . + "](" + $m.attrs.href + ")"
          else . end)
    elif .type == "hardBreak"  then "  \n"
    elif .type == "mention"    then (.attrs.text // "@user")
    elif .type == "emoji"      then (.attrs.text // .attrs.shortName // "")
    elif .type == "inlineCard" then "<" + (.attrs.url // "") + ">"
    elif .type == "blockCard" or .type == "embedCard" then "<" + (.attrs.url // "") + ">\n\n"
    elif .type == "status"     then "`" + (.attrs.text // "") + "`"
    elif .type == "date"       then ((.attrs.timestamp | tonumber / 1000 | strftime("%Y-%m-%d")) // "")
    elif .type == "paragraph"  then kids($d) + "\n\n"
    elif .type == "heading"    then ([range(.attrs.level)] | map("#") | join("")) + " " + kids($d) + "\n\n"
    elif .type == "bulletList" then
      ([.content[] | li($d; "- ")] | join("")) + (if $d == 0 then "\n" else "" end)
    elif .type == "orderedList" then
      ((.attrs.order // 1) as $start
       | [.content | to_entries[] | .key as $i | .value | li($d; "\($start + $i). ")] | join(""))
      + (if $d == 0 then "\n" else "" end)
    elif .type == "taskList" then
      ([.content[] | pad($d) + (if .attrs.state == "DONE" then "- [x] " else "- [ ] " end) + kids($d) + "\n"] | join(""))
      + (if $d == 0 then "\n" else "" end)
    elif .type == "codeBlock" then
      "```" + (.attrs.language // "") + "\n" + kids($d) + "\n```\n\n"
    elif .type == "blockquote" or .type == "panel" then
      (kids(0) | sub("\\n+$"; "") | split("\n") | map("> " + .) | join("\n")) + "\n\n"
    elif .type == "rule" then "---\n\n"
    elif .type == "table" then
      (.content[0].content | length) as $ncols
      | [ .content[]
          | "| " + ([.content[] | kids(0) | gsub("\\n+"; " ") | gsub("\\|"; "\\|") | sub("^ +"; "") | sub(" +$"; "")] | join(" | ")) + " |"
        ] as $rows
      | ([$rows[0], "|" + ([range($ncols)] | map(" --- |") | join(""))] + $rows[1:] | join("\n")) + "\n\n"
    elif .type == "mediaSingle" or .type == "mediaGroup" then
      "_[attachment: " + ([.content[]?.attrs | (.alt // .id // "file")] | join(", ")) + "]_\n\n"
    else kids($d) end;

  def adf: if . == null then "_No description._" else md(0) | sub("\\n+$"; "") end;
  def name: if . == null then "Unassigned" else .displayName end;
  def day: if . == null then "—" else .[0:10] end;
  def list: if (. // []) == [] then "—" else map(.name) | join(", ") end;

  .key as $key | .fields as $f
  | [
      "# [\($key)](\($base)/browse/\($key)): \($f.summary)",
      "",
      "| Field | Value |",
      "| --- | --- |",
      "| Type | \($f.issuetype.name // "—") |",
      "| Status | \($f.status.name // "—") |",
      "| Priority | \($f.priority.name // "—") |",
      "| Assignee | \($f.assignee | name) |",
      "| Reporter | \($f.reporter | name) |",
      (if $f.parent then "| Parent | [\($f.parent.key)](\($base)/browse/\($f.parent.key)) \($f.parent.fields.summary // "") |" else empty end),
      "| Labels | \(if ($f.labels // []) == [] then "—" else $f.labels | join(", ") end) |",
      "| Components | \($f.components | list) |",
      "| Fix versions | \($f.fixVersions | list) |",
      "| Created | \($f.created | day) |",
      "| Updated | \($f.updated | day) |",
      (if $f.duedate then "| Due | \($f.duedate) |" else empty end),
      "",
      "## Description",
      "",
      ($f.description | adf),
      "",
      (if ($f.subtasks // []) != [] then
        "## Subtasks", "",
        ($f.subtasks[] | "- [\(.key)](\($base)/browse/\(.key)) \(.fields.summary) — _\(.fields.status.name)_"),
        ""
      else empty end),
      (if ($f.issuelinks // []) != [] then
        "## Linked issues", "",
        ($f.issuelinks[]
          | if .outwardIssue then [.type.outward, .outwardIssue] else [.type.inward, .inwardIssue] end
          | "- \(.[0]) [\(.[1].key)](\($base)/browse/\(.[1].key)) \(.[1].fields.summary // "")"),
        ""
      else empty end),
      (if ($f.attachment // []) != [] then
        "## Attachments", "",
        ($f.attachment[] | "- [\(.filename)](\(.content)) (\(.size) bytes)"),
        ""
      else empty end),
      (($f.comment.comments // []) as $c
       | if $c == [] then empty else
          "## Comments (\($c | length))", "",
          ($c[] | "### \(.author | name) — \(.created | day)", "", (.body | adf), "")
        end)
    ]
  | join("\n")
' "$tmp")"

mkdir -p "$(dirname "$output")"
printf '%s\n' "$markdown" > "$output"
echo "Saved $key to $output"
