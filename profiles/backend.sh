# Backend (Supabase): github.com/RichFell/ListApp_Backend
GH_REPO="RichFell/ListApp_Backend"
BASE_BRANCH="stage"       # PRs target stage
# Local Supabase only. Anything that can reach the linked production or staging
# project is denied, even when a ticket seems to ask for it.
PROFILE_ALLOW=(
  "Bash(supabase start*)" "Bash(supabase stop*)" "Bash(supabase status*)"
  "Bash(supabase db reset*)" "Bash(supabase test db*)" "Bash(supabase db lint*)"
  "Bash(supabase db diff*)" "Bash(supabase migration new *)" "Bash(supabase gen types *)"
  "Bash(deno test*)" "Bash(deno check*)" "Bash(deno fmt*)" "Bash(deno lint*)"
  "Bash(npm test*)" "Bash(npm run *)"
)
PROFILE_DENY=(
  "Bash(supabase * --linked*)" "Bash(supabase * --db-url*)" "Bash(supabase * --project-ref*)"
  "Bash(supabase db push*)" "Bash(supabase link*)" "Bash(supabase functions deploy*)"
  "Bash(supabase secrets*)" "Bash(supabase projects*)" "Bash(supabase migration repair*)"
  "Bash(supabase migration list*)"
)
device_up() {
  docker info >/dev/null 2>&1 || log "$KEY: warning: Docker isn't running, so local Supabase tests will fail"
}
device_down() { ( cd "$WT" 2>/dev/null && supabase stop >/dev/null 2>&1 ) || true; }
prepare_worktree() { :; }
