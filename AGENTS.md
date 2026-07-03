# VlogSlate - Developer Notes

## Workflow

- Use the Makefile for routine tasks: `make clean`, `make build`, `make format`, `make lint`.
- Use `make run-device` for build, install, and launch on a connected iPhone.
- Prefer the smallest relevant build command before broad verification.
- If the user asks to perform a change in a new worktree, create that worktree under ../VlogSlate-worktrees/.

## Code Style

- When creating new source files, include the standard Xcode file comment header. Use the format below, attributing authorship to the agent on behalf of the user (replace `<username>` with the actual GitHub username if known, otherwise use the user's name; use the real creation date in `YYYY/M/D` format):
  ```
  //
  //  FileName.swift
  //  VlogSlate
  //
  //  Created by OpenAI Codex on behalf of <username> on YYYY/M/D.
  //
  ```
  Omit this header only when the user explicitly requests it.
- Follow `swift-format` and keep edits aligned with existing project style.
- Use `LocalizedStringResource` whenever possible for user-facing SwiftUI strings, including labels, helper text, and accessibility copy.

## Testing

- No test target defined for this app yet.

## Commits

- Use conventional commits: `<type>: <subject>`.
- Write imperative, capitalized subjects; keep them concise and avoid periods.
- Add a body when the change needs explanation.

## Additional Notes

- Use `@ViewBuilder` wisely. Do not simply add `return` to resolve compiler warnings.
- The app uses `@Observable` (iOS 17+) for the store — prefer `.environment(store)` and `@Environment(StoreType.self)` over `@EnvironmentObject`.
- All data persistence is JSON-based in `~/Library/Application Support/VlogSlate/footage.json`.
