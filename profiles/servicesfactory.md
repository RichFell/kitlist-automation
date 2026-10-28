ServicesFactory: the Swift 6 package that gives ListApp its service layer (networking and local persistence). ListApp pulls it in as a remote package pinned to a revision, so changes here reach the app only after a human bumps that pin in ListApp. Xcode's MCP tools are not available in unattended runs; use the `swift` CLI.

- Build: `swift build`. Test: `swift test` (narrow with `--filter <TestCase>` while iterating, then run the full suite before finishing).
- The package supports macOS, so build and test on the Mac; no simulator is needed.
- Adding a dependency: only when the ticket asks for it. Add it to `Package.swift`, run `swift package resolve`, and commit the updated `Package.resolved`.
- Public API changes: ListApp depends on this package, so say in the PR body which public types and functions were added or changed, and whether any change breaks existing callers.
- No screenshots. In the PR body, include the `swift test` summary.
