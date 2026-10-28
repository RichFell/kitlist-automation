---
description: Run the ticket runner on one Jira ticket now (e.g. /start_ticket SCRUM12)
argument-hint: SCRUM<N>
allowed-tools: Bash(./ticket-runner.sh --ticket *), Bash(tail *)
---

Run the ticket runner on the Jira ticket given in the arguments: `$ARGUMENTS`

1. Normalize the argument to a Jira key of the form `SCRUM-<N>`: uppercase it and insert the hyphen if it's missing (`SCRUM12`, `scrum-12` and `12` all become `SCRUM-12`). If it doesn't contain a ticket number, stop and ask for one instead of running anything.
2. From the repo root, run `./ticket-runner.sh --ticket SCRUM-<N>` with `run_in_background: true`. A run can take a long time (implement, self-review, then the PR), so don't wait on it in the foreground and don't poll.
3. Tell me the key you started and that progress is in `~/.kitlist-automation/logs/runner.log`.
4. When the background run finishes, report the outcome from the last lines of `~/.kitlist-automation/logs/runner.log`: the PR URL if one was opened, or the blocked reason if the ticket was sent back to To Do.
