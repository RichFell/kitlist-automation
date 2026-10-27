Supabase backend. Work against the LOCAL Supabase stack only.

- Never run anything that targets the linked production project or listapp-staging: no `--linked`, `--db-url`, `--project-ref`, `db push`, `link`, `functions deploy` or `secrets`. These are denied. Deploying is the human's job after merge.
- Start the local stack with `supabase start` if it isn't running (`supabase status`).
- Schema changes go in new migrations: `supabase migration new <snake_case_name>`. Never edit a migration that already exists on `origin/{{BASE_BRANCH}}`.
- Verify: `supabase db reset` (local) applies every migration cleanly, then `supabase test db` passes. Add pgTAP tests for new tables, RLS policies and RPCs, including a test that a user can't read or change another user's data.
- No screenshots. In the PR body, include the test summary and, for schema changes, the list of tables, policies and functions added or changed.
