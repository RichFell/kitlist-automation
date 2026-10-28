# Backend (Supabase): github.com/RichFell/kitlist-backend
GH_REPO="RichFell/kitlist-backend"
BASE_BRANCH="stage"       # PRs target stage
# Local Supabase only. Anything that can reach the linked production or staging
# project is denied, even when a ticket seems to ask for it.
PROFILE_ALLOW=(
  "Bash(supabase start*)" "Bash(supabase stop*)" "Bash(supabase status*)" "Bash(supabase --version)"
  "Bash(supabase db start*)" "Bash(supabase functions serve*)"
  "Bash(psql postgresql://postgres:postgres@127.0.0.1:54322/postgres *)"
  "Bash(docker exec supabase_db_kitlist-backend psql *)" "Bash(docker info*)" "Bash(docker ps*)"
  "Bash(supabase db reset*)" "Bash(supabase test db*)" "Bash(supabase db lint*)"
  "Bash(supabase db schema declarative sync*)" "Bash(supabase migration new *)"
  "Bash(supabase migration up --local*)" "Bash(supabase db advisors --local*)" "Bash(supabase gen types *)"
  "Bash(deno --version)" "Bash(deno test*)" "Bash(deno check*)" "Bash(deno fmt*)" "Bash(deno lint*)"
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
