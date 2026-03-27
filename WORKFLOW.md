---
tracker:
  kind: linear
  project_slug: "ai-product-factory-6ef28b56b22d"
  api_key: $LINEAR_API_KEY
  active_states:
    - Todo
    - In Progress
    - Rework
    - Human Review
    - Merging
  terminal_states:
    - Done
    - Closed
    - Cancelled
    - Canceled
    - Duplicate

polling:
  interval_ms: 5000

workspace:
  root: $SYMPHONY_WORKSPACE_ROOT
  hooks:
    after_create: |
      git clone --depth 1 "$SOURCE_REPO_URL" .

agent:
  max_concurrent_agents: 10
  max_turns: 20

codex:
  command: codex app-server
  approval_policy: never
  thread_sandbox: workspace-write
  turn_sandbox_policy:
    type: workspaceWrite
---
You are working in the `AI-Product-Factory` monorepo.

This repository is managed through one Linear project. The project contains issues for multiple services, so every issue must resolve to one primary target path before you edit anything.

Primary routing rules:

- Prefer one explicit Linear label in this set:
  - `service:ibad` -> `IBAD/app`
  - `service:translate-developer` -> `Translate-Developer`
  - `service:uggk` -> `UGGK`
  - `service:docs` -> `docs` or root-level docs
  - `service:new-service` -> a new top-level service directory named explicitly in the issue body
- If the label is missing, infer the target from a title prefix such as `[IBAD]`, `[Translate-Developer]`, or `[UGGK]`.
- If the target path is still ambiguous, stop and report the ambiguity instead of guessing.
- Do not expand scope across multiple services unless the issue explicitly says it is cross-cutting.

Repository structure:

- `IBAD/app`: Vercel app for Korean rejection-message generation
- `Translate-Developer`: Vercel app for translating developer language into plain Korean
- `UGGK`: early-stage service area; treat as docs/spec-first unless the issue explicitly asks for implementation
- `docs`: design docs and implementation plans

Execution rules:

1. Start by identifying the exact target path for the issue.
2. Read the root `README.md` and any service-local README before editing.
3. Only modify the subtree needed for the current issue.
4. Keep diffs small and reversible.
5. Never store secrets, tokens, or personal credentials in the repository, generated files, or issue comments.
6. Use SSH or preconfigured credential helpers for Git operations. Do not paste a personal access token into remotes or workflow files.
7. Do not commit directly to `main`.
8. For any issue that changes repository files, work on an issue-specific branch.
9. Use `issue.branch_name` if the tracker provides it. Otherwise derive a branch name from `issue.identifier` and the task summary.
10. If the issue requests a brand-new service, create one new top-level directory only when the issue body explicitly names the directory and desired outcome.
11. If required auth, permissions, target-path information, or GitHub tooling is missing, stop and report the blocker clearly.

Validation rules:

- If you changed `IBAD/app`, run `cd IBAD/app && npm run verify`.
- If you changed `Translate-Developer`, run `cd Translate-Developer && npm run verify`.
- If you changed only docs or planning files, run the narrowest relevant verification available and explain when no automated checks exist.
- `UGGK` does not currently expose a runnable app harness in this repository. Unless the issue explicitly defines implementation acceptance criteria, keep `UGGK` work to docs, plans, or repo scaffolding.
- If repository files changed, verification must complete before commit, push, or PR creation.

Issue handling rules:

- One Linear project is used for the entire repository. Treat labels and issue text as the routing source of truth.
- If Linear write tools are available in-session, keep issue state and comments current.
- If Linear write tools are not available, do not block code progress on tracker writes alone. Finish the code work, then report what human follow-up is still needed in Linear.

GitHub delivery rules:

- Non-code tasks whose primary output is planning, ideation, brainstorming, analysis, or recommendations do not require a branch, push, or PR by default.
- For those non-code tasks, the default handoff is a detailed Linear comment. Optional docs or plan files are supporting artifacts, not the primary communication surface.
- Do not move non-code tasks into `Merging` by default unless the issue explicitly asks for a PR-based handoff.
- For any issue that changes repository files, create or reuse the issue branch before final verification and delivery steps.
- After verification passes, create a commit with a concise message that matches the work completed.
- Push the issue branch to `origin` if Git auth is available.
- Create or update a GitHub pull request if GitHub tooling is available.
- A pull request is the default handoff for file-changing work. Do not treat local-only changes as complete delivery unless the issue explicitly says not to push.
- Pull request titles and bodies should be written in Korean by default unless the issue explicitly asks for English.
- PR descriptions should include:
  - the Linear issue identifier and title
  - a short summary of what changed
  - verification run and result
- After branch push or PR creation, post a Linear comment with the branch name, commit SHA, PR URL if available, and verification status.
- If push succeeds but PR creation is blocked by missing GitHub tooling or permissions, report that blocker clearly and include the exact branch name so a human can open the PR manually.
- If push itself is blocked by auth or remote configuration, stop before claiming handoff completion and report the exact Git blocker.

Comment feedback loop:

- Before acting on an issue in `In Progress`, `Rework`, `Human Review`, or `Merging`, fetch the latest Linear comments if comment-reading tools are available.
- Treat any recent comment not authored by the current agent or an obvious automation bot as human feedback that may change the task.
- Do not ignore new human feedback just because the issue title or state did not change.
- If multiple human comments conflict, follow the newest specific instruction and clearly report the conflict.
- Ignore pure automation noise and your own previous progress comments unless a human explicitly refers back to them.
- If comment-reading tools are unavailable, continue with the issue body and current state, but explicitly report that the latest comment feedback could not be checked.
- After meaningful progress, post a fresh Linear comment if comment-writing tools are available.
- Every update comment should be concrete, short, and action-oriented.
- Never leave a comment that only says the work was documented in a file. A doc path may be included, but the important content must be readable from the Linear comment itself.
- If a supporting doc or plan file was created, summarize the useful parts inline first, then reference the file path as supplemental detail.
- If the work is too large to describe line by line, provide a short high-signal summary plus the most important concrete points instead of dumping every detail.
- For planning, ideation, brainstorming, product thinking, or research tasks, the update comment must include:
  - what the user asked for
  - the recommendation or current conclusion
  - key options or tradeoffs considered
  - why the recommendation was chosen
  - open questions, risks, or decisions still needed
  - optional supporting doc path if one was written
- For code changes, the update comment must include:
  - why the change was made
  - what changed
  - exact paths touched
  - the most important code or behavior changes summarized in plain language
  - user-visible impact or expected product behavior change
  - verification run and result
  - how a human can check the change
  - preview URL, deployed URL, or local run instructions when the change affects a testable app or website and that information is available
  - any remaining blocker or decision needed
- For non-code work, the update comment must include:
  - what changed
  - the actual substance of the recommendation or artifact, not just its filename
  - which docs, plans, or artifacts were updated
  - what decision or review is needed next
- If comment-writing tools are unavailable, include the exact comment you would have posted in the final response so a human can paste it.

State routing rules:

- `Todo`: start new work for the routed target path.
- `In Progress`: continue implementation and validation for the routed target path. If the task is code-changing, maintain the issue branch and keep delivery headed toward a pushed branch and PR. If the task is planning or ideation, keep the comment thread rich enough that a human can react without opening repository files first.
- `Rework`: read the latest human comments first, convert them into the current task list, address that feedback, keep scope tight, rerun the relevant verification, and leave a new update comment describing what changed.
- `Human Review`: do not widen scope or start unrelated work. Review the latest human comments, PR state, and checks if those tools are available. If there is actionable feedback, address it, rerun verification, push updated commits if needed, update the PR if one exists, and leave a new update comment. If there is no actionable feedback, report that the issue is waiting on human review.
- `Merging`: use this state only for code-changing work that should land through GitHub. If no PR exists yet, first confirm the issue branch is pushed and create or update the PR. Do not sit idle waiting for merge readiness when the PR has not been opened. Once a PR exists, review the latest human comments and checks before merge work. Confirm the latest relevant verification is still green. If the repository has a configured safe merge flow, use it. If merge tooling or permissions are missing, report the exact merge blocker instead of forcing a risky manual sequence.

Final response requirements:

- Summarize what changed.
- List the exact paths touched.
- Report the verification you ran and whether it passed.
- For file-changing work, report the branch name, commit SHA, and PR URL if available.
- Report blockers only when they actually prevented completion.
