# Symphony Monorepo Integration Design

## Summary

`AI-Product-Factory` will integrate Symphony at the repository level, not per app. One Linear project will represent the whole repository, and service-level routing will be handled by labels and issue wording inside that shared project.

## Approved Decisions

- Scope: repository-wide Symphony orchestration
- Tracker shape: one Linear project for the full repository
- Routing: service labels and explicit issue wording
- Delivery mode: branch, commit, push, and PR for file-changing issues
- Delivery mode for planning/ideation work: detailed Linear comment first, optional doc artifact second
- PR language: Korean by default
- Initial safety posture: `approval_policy: never` inside headless Symphony workers
- Turn sandbox posture: `workspaceWrite` with `networkAccess: true` so unattended GitHub PR lookups/creation can succeed
- Initial concurrency: `max_concurrent_agents: 10`
- Initial dispatch states: `Todo`, `In Progress`, `Rework`, `Human Review`, `Merging`
- Workspace strategy: one isolated workspace per issue under `SYMPHONY_WORKSPACE_ROOT`
- Clone strategy: use `SOURCE_REPO_URL` so credentials are kept outside the repository

## Why One Linear Project

The current public Symphony workflow shape centers on one `tracker.project_slug` per workflow file. For this repository, one shared Linear project is simpler than creating a separate Symphony instance for every service.

This repository behaves more like a studio than a single product. Services are added, revised, or abandoned over time. A shared project keeps queue management simple while still allowing strong service boundaries through labels.

## Routing Model

Each issue must declare one primary target:

- `service:ibad` -> `IBAD/app`
- `service:translate-developer` -> `Translate-Developer`
- `service:uggk` -> `UGGK`
- `service:docs` -> `docs` or root docs
- `service:new-service` -> new top-level directory named in the issue body

If the label is missing, the workflow may fall back to title prefixes such as `[IBAD]` or `[Translate-Developer]`. If the target is still unclear, the agent should stop rather than guess.

## Operational Rules

- Default to changing one service subtree per issue.
- Cross-cutting work must be explicitly declared in the issue.
- New service creation must name the exact target directory in the issue body.
- Secrets and credentials stay in environment variables, not in repository files.
- Git operations should use SSH or external credential helpers, never embedded personal access tokens.
- File-changing issues should not be considered delivered until they are committed and pushed.
- The default handoff for file-changing work is an open or updated pull request, not an unpushed local branch.
- The default handoff for planning, ideation, brainstorming, and analysis work is a rich Linear comment, not "see the doc".
- `Human Review` and `Rework` should be comment-driven states, not passive holding buckets.
- Latest human comments should be treated as task-shaping input when the tooling can read them.
- After meaningful progress, the agent should leave a fresh summary comment when the tooling can write it.

## Validation Strategy

Current service-level verification:

- `IBAD/app`: `npm run verify`
- `Translate-Developer`: `npm run verify`
- `UGGK`: no standard executable harness yet, so default to docs/plans unless the issue explicitly defines implementation and validation expectations

Docs-only changes should use the narrowest available verification and clearly state when no automated checks exist.

## Comment Feedback Design

The repository-level workflow should support this loop:

1. Agent completes a pass and hands off at `Human Review`.
2. Human leaves one or more Linear comments.
3. Issue returns to `Rework` or `In Progress`.
4. Agent reads the latest human comments, updates the work, reruns verification, and posts a new summary comment.

Important behavior:

- Human comments are higher priority than the agent's earlier self-authored comments.
- Bot noise or stale status updates should not override newer human direction.
- Comments should contain the useful substance inline; artifact paths are supplemental.
- Code updates should be summarized with why the change was made, exact paths touched, key behavior changes, verification run, how to check the result, branch name, and PR link when available.
- Non-code updates should be summarized with the actual recommendation, tradeoffs, and next decision needed, with updated artifacts only as support.
- `Merging` should not be a passive waiting room. If the issue belongs in GitHub handoff and no PR exists yet, opening or updating the PR is the first responsibility of that state.
- Planning or brainstorming work should normally stop at comment-first handoff states instead of entering `Merging`.

## GitHub Delivery Design

For file-changing issues, the intended repository flow is:

1. create or reuse an issue branch
2. implement the change
3. run the relevant verification
4. commit the verified result
5. push the branch
6. create or update a pull request
7. leave a Linear comment with branch, commit, PR URL, and verification

If push or PR creation is blocked by missing tooling or permissions, the workflow should report the exact blocker instead of pretending the issue is fully handed off.

## Initial Rollout

Start with a conservative unattended setup:

1. Create one Linear project for the repository.
2. Add the required workflow states.
3. Add service labels.
4. Fill in the actual project slug in the root `WORKFLOW.md`.
5. Run one Symphony instance against that workflow.
6. Keep concurrency low until the issue-routing conventions prove stable.

## Follow-Up Documentation

The repository should keep two root-level operational artifacts in sync:

- `WORKFLOW.md`
- `README.md`

When a new service is added, both files should be updated so Symphony routing and validation expectations remain explicit.
