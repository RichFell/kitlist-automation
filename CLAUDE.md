# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A bash-only runner, started hourly by launchd on the owner's Mac. It takes Jira tickets from the "Ready for Claude" column and runs `claude -p` twice in a fresh git worktree: once to implement the ticket and once, in a session that hasn't seen that work, to self-review it. The runner then pushes the branch, opens a GitHub PR and moves the card to "In Review". README.md covers the user-facing flow and setup.

## Commands

There is no build, lint or test suite. To check changes:

- Syntax check: `bash -n ticket-runner.sh install.sh lib/*.sh profiles/*.sh`
- Show what would be picked up without changing anything: `./ticket-runner.sh --dry-run`. This needs the Jira token in the Keychain and `gh` signed in.
- Run one ticket now: `./ticket-runner.sh --ticket SCRUM-12`. This is a real run: it moves the Jira card, pushes a branch and opens a PR.
- Copy changes to the installed runner: `./install.sh`. launchd runs a copy in `~/.kitlist-automation/app` because background jobs can't read `~/Documents`, so edits here have no effect on the hourly job until you re-run this. `--reset-token` stores a new Jira token and `--uninstall` stops the hourly job.
- Runtime state lives in `~/.kitlist-automation/`: `logs/runner.log`, `runs/<KEY>-<time>/` (ticket brief, `implement.json`/`review.json` transcripts, PR body, screenshots), plus the runner's own `repos/` clones and `worktrees/`.

## Architecture

- `ticket-runner.sh`: the entry point. It sources `config.sh` and then `lib/{common,jira,devices,pipeline}.sh`. It takes a lock, searches Jira, skips tickets with unfinished "is blocked by" links, and calls `process_ticket` in a subshell for each ticket, up to `MAX_TICKETS_PER_RUN`.
- `lib/pipeline.sh` `process_ticket`:
  1. Platform labels go through `targets_for_labels` and then `profile_for_targets`, which returns `ios`, `android`, `backend` or `servicesfactory`. All labels on a ticket must map to one repo.
  2. The runner sources `profiles/<profile>.sh`. Each profile sets `GH_REPO`, `BASE_BRANCH`, `PROFILE_ALLOW`/`PROFILE_DENY` and the hooks `device_up`, `device_down` and `prepare_worktree`.
  3. The branch is named `$(branch_prefix <issuetype>)/<KEY>`, so `bugs/`, `feature/` or `task/` followed by the key. An open PR on that branch means the ticket is already done; a remote branch with no PR fails the ticket so nobody's work gets overwritten.
  4. The implement phase runs, then the review phase. Every step after the implement phase is done by the runner itself: pushing the branch, uploading screenshots to the repo's orphan `pr-assets` branch, `gh pr create`, and the Jira updates.
- Each phase talks back through files in `$RUN_DIR`. Claude must write `status.json` (`{"status":"done"|"blocked","reason":...}`), which `require_done` enforces. `pr-body.md` becomes the PR description and `screenshots/*.png` are attached to the PR. Devices are listed in `devices.txt`. Any failure goes through `fail_ticket`, which moves the card back to To Do, adds the `claude-blocked` label and posts a Jira comment.
- Prompts: `prompts/implement.md` and `prompts/review.md` are filled in by `render_template`, which replaces `{{KEY}}`, `{{BRANCH}}`, `{{BASE_BRANCH}}`, `{{RUN_DIR}}`, `{{TARGETS}}` and `{{PROFILE}}`. `{{PROFILE}}` becomes the text of `profiles/<profile>.md`, the repo-specific build, test and screenshot instructions. It is replaced first, so placeholders inside a profile `.md` are filled in too.
- Permissions are the security boundary. `write_settings` builds a fresh settings JSON for each phase from `COMMON_ALLOW`/`COMMON_DENY` plus the profile's lists. The JSON lives outside every directory Claude can write to. Edits to that file and to `.claude/` in the worktree and `RUN_DIR` are denied, so a phase can't widen the permissions of a later phase. Claude must never be allowed to push, switch branches, run `gh` or `curl`, read the Keychain, or reach remote Supabase. When adding allow rules, keep the matching deny rules intact.

## Conventions

- Scripts must run on macOS's stock **bash 3.2**: no associative arrays, no `mapfile`, and no `${var,,}`. Use `tr` for case changes. Expand arrays that might be empty with `${arr[@]+"${arr[@]}"}`.
- Ticket keys end up in URLs and in paths that get `rm -rf`, so always check them with `valid_key` before using them.
- The Jira token is read from the Keychain only (`security find-generic-password`), never from files or env vars.
- `_to_delete/` holds scratch files and is excluded from the installed copy.
