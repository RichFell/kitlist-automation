# Shared helpers. Written for the bash 3.2 that ships with macOS.
shopt -u patsub_replacement 2>/dev/null || true   # bash 5.2+: keep "&" literal in replacements

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE" >&2; }
die() { log "ERROR: $*"; exit 1; }

LOCK_DIR="$STATE_DIR/runner.lock"
acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then echo $$ > "$LOCK_DIR/pid"; return 0; fi
  local pid; pid="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    log "Previous run (pid $pid) is still working; skipping this one."; return 1
  fi
  log "Clearing a stale lock."; rm -rf "$LOCK_DIR"
  mkdir "$LOCK_DIR" && echo $$ > "$LOCK_DIR/pid"
}
release_lock() { [ "$(cat "$LOCK_DIR/pid" 2>/dev/null)" = "$$" ] && rm -rf "$LOCK_DIR"; return 0; }

preflight() {
  local c missing=""
  for c in git gh jq claude curl security caffeinate; do
    command -v "$c" >/dev/null 2>&1 || missing="$missing $c"
  done
  [ -z "$missing" ] || { log "Missing tools:$missing"; return 1; }
  gh auth status >/dev/null 2>&1 || { log "GitHub CLI isn't signed in (run: gh auth login)."; return 1; }
}

# render_template FILE NAME VALUE [NAME VALUE ...] -> replaces {{NAME}} with VALUE
render_template() {
  local t; t="$(cat "$1")"; shift
  while [ $# -gt 1 ]; do t="${t//\{\{$1\}\}/$2}"; shift 2; done
  printf '%s\n' "$t"
}

# Prints a JSON array of its arguments.
json_array() { if [ $# -eq 0 ]; then echo '[]'; else printf '%s\n' "$@" | jq -R . | jq -s .; fi; }

# Keys end up in URLs and in paths that get rm -rf, so only accept real Jira keys.
valid_key() { printf '%s' "$1" | grep -qE '^[A-Z][A-Z0-9]*-[0-9]+$'; }

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//' | cut -c1-40 | sed 's/-$//'
}

# Platform a single label stands for (empty if it isn't a platform label).
label_target() {
  case "$1" in
    ios|area-ios) echo ios ;;
    watchos|area-watchos) echo watchos ;;
    android|area-android) echo android ;;
    wearos|area-wearos) echo wearos ;;
    backend|area-backend) echo backend ;;
  esac
}
target_repo() {
  case "$1" in ios|watchos) echo ios ;; android|wearos) echo android ;; backend) echo backend ;; esac
}

# Space-separated platform targets in a ticket's labels, e.g. "ios watchos".
targets_for_labels() {
  local l t out=" "
  for l in $1; do
    t="$(label_target "$l")"
    [ -n "$t" ] || continue
    case "$out" in *" $t "*) ;; *) out="$out$t " ;; esac
  done
  out="${out# }"; printf '%s' "${out% }"
}

# Which repo profile the targets belong to. All targets must live in one repo.
profile_for_targets() {
  local t p found=""
  for t in $1; do
    p="$(target_repo "$t")"
    if [ -n "$found" ] && [ "$found" != "$p" ]; then return 1; fi
    found="$p"
  done
  [ -n "$found" ] && echo "$found"
}
