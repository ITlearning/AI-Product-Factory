# AI-Product-Factory

This repository is a collection of small product and service experiments. The recommended Symphony setup is one Linear project for the whole repository, with service routing handled by labels and issue wording instead of one Linear project per app.

Repository guidance files:

- [`AGENTS.md`](AGENTS.md): repo-level Codex guidance and short map
- [`WORKFLOW.md`](WORKFLOW.md): Symphony runtime config plus orchestration prompt

## Recommended Linear Shape

Use one Linear project, for example `AI Product Factory`, and keep one Symphony runner attached to that project slug.

Recommended workflow states:

- `Todo`
- `In Progress`
- `Human Review`
- `Merging`
- `Rework`
- `Done`

Current Symphony dispatch states in the checked-in workflow draft:

- `Todo`
- `In Progress`
- `Rework`
- `Human Review`
- `Merging`

Recommended service labels:

- `service:ibad`
- `service:translate-developer`
- `service:uggk`
- `service:docs`
- `service:new-service`

Recommended issue-writing rules:

- Every issue should identify exactly one primary target service.
- New service issues should name the exact directory to create.
- Cross-cutting issues should say that they are allowed to touch multiple services.
- Include acceptance criteria and validation notes when the task is not obvious from the title.

## Why One Linear Project

The current public Symphony workflow shape uses a single `tracker.project_slug` per `WORKFLOW.md`. That makes one shared Linear project the simplest operating model for this monorepo.

Use labels to route work inside the single project:

- `service:ibad` for [`IBAD/app`](IBAD/app)
- `service:translate-developer` for [`Translate-Developer`](Translate-Developer)
- `service:uggk` for [`UGGK`](UGGK)
- `service:docs` for [`docs`](docs)

If you later want independent queues, you can run multiple Symphony processes with separate workflow files and separate Linear project slugs.

## Required Environment Variables

Before starting Symphony, set:

```bash
export LINEAR_API_KEY="your-linear-token"
export SOURCE_REPO_URL="git@github.com:ITlearning/AI-Product-Factory.git"
export SYMPHONY_WORKSPACE_ROOT="$HOME/code/ai-product-factory-workspaces"
```

Notes:

- Use an SSH clone URL or a credential-helper-backed remote.
- Do not embed a GitHub personal access token in `WORKFLOW.md`.
- The root workflow file in this repo is [`WORKFLOW.md`](WORKFLOW.md).
- For unattended push/PR flows, the repository remote should not be a token-in-URL HTTPS remote.

## Installing Symphony

The easiest starting point is the OpenAI reference implementation:

```bash
git clone https://github.com/openai/symphony.git "$HOME/code/symphony"
cd "$HOME/code/symphony/elixir"
mise trust
mise install
mise exec -- mix setup
mise exec -- mix build
```

The checked-in [`WORKFLOW.md`](WORKFLOW.md) already points at the current Linear project slug:

- `ai-product-factory-6ef28b56b22d`

## Running Symphony For This Repo

After setting the environment variables:

```bash
cd /path/to/symphony/elixir
./bin/symphony /Users/tabber/AI-Product-Factory/WORKFLOW.md --port 4000 \
  --i-understand-that-this-will-be-running-without-the-usual-guardrails
```

On the current machine, the existing Symphony checkout is:

```bash
cd /Users/tabber/Desktop/github/symphony/elixir
```

This starts the Symphony service against the single Linear project and serves the optional dashboard on port `4000`.

The current Symphony Elixir reference implementation requires this explicit acknowledgement flag because it is a low-key engineering preview intended for evaluation only.

The checked-in workflow uses `approval_policy: never` for Codex. In this headless Symphony setup, `on-request` causes agent runs to fail whenever Codex asks for approval for commands like worktree creation, push, or PR creation.

The checked-in workflow will also dispatch `Human Review` and `Merging` issues. Those states should be used only if your PR/review and merge process is already wired well enough for unattended handling.

The current checked-in concurrency is `10` agents. This is still a fairly aggressive setting and assumes your Linear routing, local machine capacity, and Git/PR workflow are stable enough to handle multiple concurrent issue runs.

## GitHub Delivery Flow

The checked-in workflow now assumes `B`-level delivery for file-changing issues:

1. make the change on an issue-specific branch
2. run verification
3. commit the work
4. push the branch to GitHub
5. create or update a pull request
6. post a Linear comment with branch, commit, PR link, and verification status

Important prerequisites:

- `origin` should use SSH or another non-embedded credential flow
- the runtime must have Git push permission
- the runtime must have GitHub PR creation capability, such as `gh` auth or an equivalent GitHub tool

If PR creation tooling is missing, the workflow should still push the branch and then report the exact manual follow-up needed.

This PR-oriented flow is for file-changing code work. For planning, ideation, brainstorming, or recommendation-heavy tasks, the default handoff is a detailed Linear comment, not a PR.

State intent:

- `Human Review` is the default handoff for non-code work and for code work that still needs human feedback.
- `Merging` is for code-changing work that should land through GitHub.
- If an issue reaches `Merging` without an open PR, the agent should open or update the PR first instead of idling.
- Planning or brainstorming issues should not be moved to `Merging` unless a PR-based handoff was explicitly requested.

PR language rule:

- PR 제목과 본문은 기본적으로 한국어로 작성합니다.
- 이슈에서 영어를 명시적으로 요구한 경우에만 영어로 작성합니다.

## How Routing Works In Practice

Symphony reads the issue from one Linear project, then the prompt in [`WORKFLOW.md`](WORKFLOW.md) routes the work to the right subtree.

Examples:

- `[IBAD] tighten unsupported-scope messaging` + `service:ibad`
- `[Translate-Developer] add source badge copy` + `service:translate-developer`
- `[UGGK] write MVP design` + `service:uggk`
- `[Docs] document deployment setup` + `service:docs`

For a brand-new app, create an issue like:

- title: `[New Service] create landing-page-generator`
- label: `service:new-service`
- body: include `Target directory: landing-page-generator`

Without an explicit target directory, the workflow should stop instead of guessing.

## Comment-Driven Rework Loop

The workflow is set up so `Human Review` and `Rework` are not passive parking states.

Recommended pattern:

1. Agent finishes a first pass and leaves the issue in `Human Review`.
2. A human leaves one or more Linear comments with feedback or follow-up direction.
3. Move the issue to `Rework` or back to `In Progress`.
4. Symphony should read the latest human comments, update the work, and post a fresh summary comment.

Expected comment behavior:

- Human-authored comments are treated as new instructions, even if the issue title did not change.
- Agent-authored or bot-authored status comments should not override newer human feedback.
- Comments should be readable on their own. The agent should not force the human to open a repo file just to understand the result.
- If a doc or plan file was written, the important contents should still be summarized inline in the comment.
- After code changes, the agent should comment with:
  - why the change was made
  - exact paths touched
  - what changed in plain language
  - expected user-visible impact
  - verification run and result
  - how to check the change
  - branch name and PR link when available
- After non-code changes, the agent should comment with:
  - the actual recommendation, idea, or conclusion
  - key tradeoffs or alternatives considered
  - any open question or decision needed next
  - updated docs/plans/artifacts as supplemental references

Recommended review posture:

- For planning work, respond to the recommendation and tradeoffs in the Linear comment thread.
- For code work, use the Linear comment plus the PR together: the PR is the diff surface, and the Linear comment is the human-readable summary and test guidance.

## Service-Specific Verification

Current verification commands:

- [`IBAD/app`](IBAD/app): `cd IBAD/app && npm run verify`
- [`Translate-Developer`](Translate-Developer): `cd Translate-Developer && npm run verify`
- [`UGGK`](UGGK): currently docs/spec-first; no standard app verification command yet

If a new service is added, update both [`WORKFLOW.md`](WORKFLOW.md) and this README so the routing and validation rules stay explicit.
