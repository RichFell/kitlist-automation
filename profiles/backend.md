Supabase backend. Follow the repo's `CLAUDE.md` for the schema workflow (declarative schemas in `supabase/schemas/`, generated migrations), security rules and test conventions. The rules below are specific to this runner.

- Work against the LOCAL Supabase stack only. Start it with `supabase start` if `supabase status` shows it isn't running.
- Never run anything that targets a hosted project (`kitlist-staging` or `kitlist-production`): no `--linked`, `--db-url`, `--project-ref`, `db push`, `link`, `functions deploy` or `secrets`. These are denied. Deploying is the human's job after merge.
- Never edit a migration that already exists on `origin/{{BASE_BRANCH}}`.
- Before finishing, `supabase db reset && supabase test db` must pass and `supabase db advisors --local` must report nothing new.
- No screenshots. In the PR body, include the test summary and, for schema changes, the list of tables, policies and functions added or changed.
