# Kitlist ticket runner

Drag a Jira card into **Ready for Claude**. Within the hour, this Mac picks it up and runs Claude Code to implement it and self-review the work, then opens a GitHub PR with screenshots. The card moves to **In Review**, and you review and merge.

It runs on your Mac with your Claude plan, GitHub sign-in and Jira token, so there are no GitHub Actions minutes or paid Jira automation involved.

## How a ticket flows

1. **Pickup.** Every hour, while the Mac is awake, the runner takes the top card in Ready for Claude.
   - It only takes cards with the `ai-ready` label (`READY_LABEL` in `config.sh`) and skips cards with the `claude-blocked` label.
   - It skips cards that are "blocked by" an unfinished ticket.
   - It moves the card it takes to In Progress.
2. **Routing.** The card's platform labels pick the repo and the devices to start:

   | Label | Repo | Devices started |
   |---|---|---|
   | `ios` | RichFell/kitlist-ios | iPhone simulator |
   | `android` | RichFell/kitlist-android | phone emulator |
   | `backend` | RichFell/kitlist-backend | none (local Supabase) |
   | `servicesfactory` | RichFell/kitlist-ios-services | none (builds and tests on the Mac) |

   The `area-` versions of these labels work too. Labels from different repos get the ticket sent back. watchOS and Wear OS aren't supported yet; those labels are ignored.
3. **Fresh worktree.** The runner keeps its own clones under `~/.kitlist-automation/repos`, so your working copies are never touched. Each ticket gets a fresh worktree named for the ticket type (`bugs/<KEY>` for a Bug, `feature/<KEY>` for a Story, `task/<KEY>` for a Task or anything else), made from `develop` (`stage` for the backend, `main` for kitlist-ios-services). PRs target that same branch, and you merge releases into the default branch yourself.
4. **Implement.** Claude Code reads the ticket and the repo's `CLAUDE.md`. It implements the ticket, builds, tests, takes screenshots and commits. It isn't allowed to push, change branches, call GitHub or Jira, or touch remote Supabase projects.
5. **Self-review.** A second Claude Code session that hasn't seen the work reviews the diff against the acceptance criteria and CLAUDE.md. It fixes real problems and adds a Self-review section to the PR description.
6. **Pull request.** The runner, not Claude, pushes the branch. It uploads screenshots to the repo's `pr-assets` branch and opens the PR. Then it moves the card to In Review and comments with the PR link.

If anything fails, or Claude decides the ticket is too unclear to build without guessing, the card goes back to **To Do** with the `claude-blocked` label and a comment explaining why. To retry, fix the ticket, remove the label and drag the card back.

## One-time setup

1. **Jira:** on the ListApp board, add a column named exactly `Ready for Claude`. Put it between To Do and In Progress. In Review already exists.
2. **Tools:** run `brew install gh jq`, then `gh auth login`. Make sure Claude Code works in Terminal by running `claude`.
3. **Android emulator:** make sure a phone AVD exists in Android Studio's Device Manager.
4. **Backend tests:** Docker Desktop needs to be running for the local Supabase tests.
5. **Install:** run `./install.sh` from this folder. It asks for a Jira API token once and stores it in the Keychain, then starts the hourly job.

After editing anything in this folder, run `./install.sh` again. The hourly job runs from an installed copy in `~/.kitlist-automation/app`, because macOS doesn't let background jobs read Documents.

## Day to day

- **See what would be picked up:** `~/.kitlist-automation/app/ticket-runner.sh --dry-run`
- **Work one ticket now:** `~/.kitlist-automation/app/ticket-runner.sh --ticket SCRUM-12`
- **Follow along:** `tail -f ~/.kitlist-automation/logs/runner.log`
- **Inspect a run:** each run keeps a folder in `~/.kitlist-automation/runs/<KEY>-<time>/` with:
  - the ticket brief
  - Claude's transcripts (`implement.json`, `review.json`)
  - the PR body
  - the screenshots
- **Stop the hourly job:** `./install.sh --uninstall`

## Writing tickets that work well

- Give each ticket the platform labels it touches, all from one repo: `ios`, `android`, `backend` or `servicesfactory`, plus `ai-ready` once it has no open questions. Split features that span repos into one ticket per repo under a parent Epic that holds the shared spec, and link app tickets as "is blocked by" the backend ticket.
- Write testable acceptance criteria, and say which screens or states the screenshots should show.
- Link the Figma frame. For iOS and Android tickets, if the claude.ai Figma connector is connected, Claude checks the design against the frame. Otherwise it says in the PR that it worked from the ticket text.
- Use Jira's "is blocked by" links for ordering. The runner won't start a ticket until its blockers are done.

## Settings

Change these in `config.sh` and the files in `profiles/`:

- **`config.sh`:**
  - column names
  - tickets per run (default 1)
  - turn limits
  - model for each phase (review defaults to Sonnet), the Explore subagent model, and effort
  - the built-in tools each phase loads (`CLAUDE_TOOLS`); `USE_SUBAGENTS=1` in a profile adds Explore subagents
- **`profiles/*.sh`, per repo:**
  - base branch (`develop` for both apps; `main` for kitlist-ios-services; `stage` for the backend)
  - simulator and emulator names
  - the extra commands Claude may run
- **`profiles/*.md`:** how Claude builds, tests and captures screenshots in each repo.
- **`prompts/`:** the implement and self-review instructions.
