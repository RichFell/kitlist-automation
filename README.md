# ListApp ticket runner

Drag a Jira card into **Ready for Claude**. Within the hour, this Mac picks it up and runs Claude Code to implement it and self-review the work, then opens a GitHub PR with screenshots. The card moves to **In Review**, and you review and merge.

It runs on your Mac with your Claude plan, GitHub sign-in and Jira token, so there are no GitHub Actions minutes or paid Jira automation involved.

## How a ticket flows

1. **Pickup.** Every hour, while the Mac is awake, the runner takes the top card in Ready for Claude.
   - It skips cards with the `claude-blocked` label.
   - It skips cards that are "blocked by" an unfinished ticket.
   - It moves the card it takes to In Progress.
2. **Routing.** The card's platform labels pick the repo and the devices to start:

   | Label | Repo | Devices started |
   |---|---|---|
   | `ios` | RichFell/ListApp | iPhone simulator |
   | `watchos` | RichFell/ListApp | Apple Watch simulator |
   | `android` | RichFell/ListApp_Android | phone emulator |
   | `wearos` | RichFell/ListApp_Android | Wear OS emulator |
   | `backend` | RichFell/ListApp_Backend | none (local Supabase) |

   The `area-` versions of these labels work too. A ticket can combine labels from the same repo, such as `ios` + `watchos`. Labels from different repos get the ticket sent back.
3. **Fresh worktree.** The runner keeps its own clones under `~/.listapp-automation/repos`, so your working copies are never touched. Each ticket gets a fresh worktree named for the ticket type (`bugs/<KEY>` for a Bug, `feature/<KEY>` for a Story, `task/<KEY>` for a Task or anything else), made from `develop`. PRs target `develop`, and you merge releases into the default branch yourself.
4. **Implement.** Claude Code reads the ticket and the repo's `CLAUDE.md`. It implements the ticket, builds, tests, takes screenshots and commits. It isn't allowed to push, change branches, call GitHub or Jira, or touch remote Supabase projects.
5. **Self-review.** A second Claude Code session that hasn't seen the work reviews the diff against the acceptance criteria and CLAUDE.md. It fixes real problems and adds a Self-review section to the PR description.
6. **Pull request.** The runner, not Claude, pushes the branch. It uploads screenshots to the repo's `pr-assets` branch and opens the PR. Then it moves the card to In Review and comments with the PR link.

If anything fails, or Claude decides the ticket is too unclear to build without guessing, the card goes back to **To Do** with the `claude-blocked` label and a comment explaining why. To retry, fix the ticket, remove the label and drag the card back.

## One-time setup

1. **Jira:** on the ListApp board, add a column named exactly `Ready for Claude`. Put it between To Do and In Progress. In Review already exists.
2. **Tools:** run `brew install gh jq`, then `gh auth login`. Make sure Claude Code works in Terminal by running `claude`.
3. **Android repo:** it has no GitHub remote or `develop` branch yet. From `ListApp_Android`, run:
   `gh repo create RichFell/ListApp_Android --private --source . --push`
   `git branch develop main && git push -u origin develop`
4. **Android emulators:** make sure a phone AVD exists in Android Studio's Device Manager. When Wear OS work starts, add a Wear OS AVD too; the runner finds it by "wear" in its name.
   **Apple Watch:** watchOS tickets use the first installed Apple Watch simulator, unless you set `WATCH_SIM_NAME` in `profiles/ios.sh`.
5. **Backend tests:** Docker Desktop needs to be running for the local Supabase tests.
6. **Install:** run `./install.sh` from this folder. It asks for a Jira API token once and stores it in the Keychain, then starts the hourly job.

After editing anything in this folder, run `./install.sh` again. The hourly job runs from an installed copy in `~/.listapp-automation/app`, because macOS doesn't let background jobs read Documents.

## Day to day

- **See what would be picked up:** `~/.listapp-automation/app/ticket-runner.sh --dry-run`
- **Work one ticket now:** `~/.listapp-automation/app/ticket-runner.sh --ticket SCRUM-12`
- **Follow along:** `tail -f ~/.listapp-automation/logs/runner.log`
- **Inspect a run:** each run keeps a folder in `~/.listapp-automation/runs/<KEY>-<time>/` with:
  - the ticket brief
  - Claude's transcripts (`implement.json`, `review.json`)
  - the PR body
  - the screenshots
- **Stop the hourly job:** `./install.sh --uninstall`

## Writing tickets that work well

- Give each ticket the platform labels it touches, all from one repo: `ios`/`watchos` or `android`/`wearos` or `backend`. Split features that span repos into one ticket per repo under a parent story.
- The first watchOS ticket should be a human one: adding the watch target means editing the Xcode project file, which Claude isn't allowed to do. Once the target exists, Claude can build features in it.
- Write testable acceptance criteria, and say which screens or states the screenshots should show.
- Link the Figma frame. If Claude Code on this Mac has a Figma MCP server configured, it checks the design against the frame. Otherwise it says in the PR that it worked from the ticket text.
- Use Jira's "is blocked by" links for ordering. The runner won't start a ticket until its blockers are done.

## Settings

Change these in `config.sh` and the files in `profiles/`:

- **`config.sh`:**
  - column names
  - tickets per run (default 1)
  - turn limits
  - model
- **`profiles/*.sh`, per repo:**
  - base branch (`develop` for both apps; backend uses the GitHub default branch)
  - simulator and emulator names
  - the extra commands Claude may run
- **`profiles/*.md`:** how Claude builds, tests and captures screenshots in each repo.
- **`prompts/`:** the implement and self-review instructions.
