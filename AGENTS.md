# AI-Product-Factory Agent Guide

This file is the repository entrypoint for Codex-style agents working directly in this monorepo.

For Symphony runtime configuration, Linear polling, dispatch states, and headless delivery rules, see [`WORKFLOW.md`](WORKFLOW.md). `AGENTS.md` is the repository guidance file. `WORKFLOW.md` is the Symphony orchestration contract.

## Repo Map

- [`IBAD/app`](IBAD/app): Korean rejection-message web app
- [`Translate-Developer`](Translate-Developer): developer-language-to-plain-Korean web app
- [`UGGK`](UGGK): early-stage area; treat as docs/spec-first unless the task explicitly asks for implementation
- [`docs`](docs): plans, design notes, and supporting documentation

## Source Of Truth

- Use this file as the short map.
- Use [`README.md`](README.md) for repo-level operating notes.
- Use [`WORKFLOW.md`](WORKFLOW.md) for Symphony-specific automation behavior.
- Use files under [`docs`](docs) for supporting plans and design history.

Do not force humans to open a repo file just to understand the result of a task. Docs are supporting artifacts, not a substitute for a readable summary in the issue or PR.

## Routing

Default to one primary target path per task:

- `IBAD/app`
- `Translate-Developer`
- `UGGK`
- `docs`

Do not widen scope across multiple services unless the task explicitly says it is cross-cutting.

## Validation

- If you change [`IBAD/app`](IBAD/app), run `cd IBAD/app && npm run verify`
- If you change [`Translate-Developer`](Translate-Developer), run `cd Translate-Developer && npm run verify`
- If you only change docs or planning files, run the narrowest relevant verification and state when no automated checks exist
- `UGGK` currently has no standard app verification command in this repo

## Delivery

For code-changing work:

- work on a branch, not directly on `main`
- verify before commit and push
- default handoff is a PR
- PR title and body should be in Korean unless the task explicitly asks for English
- summarize the change in plain language, including what changed, why, expected user impact, and how to check it

For planning, ideation, brainstorming, and recommendation-heavy work:

- default handoff is a detailed human-readable summary, not “see the doc”
- docs or plan files are optional supporting artifacts

## Communication

When reporting work, include the useful substance inline:

- for code: why changed, paths touched, behavior change, verification, how to test
- for non-code: recommendation, tradeoffs, open questions, next decision needed

Avoid comments or PR descriptions that only point to a file path without summarizing the important content.
