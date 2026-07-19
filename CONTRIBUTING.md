# Contributing to EyeBreak

EyeBreak uses an issue-driven workflow. Every unit of work flows through the same loop, whether it comes from a maintainer, a contributor, or an AI agent.

## The loop

```
Issue → Implementation Plan → feature branch → atomic commits → PR to dev → human review → squash merge → release to main
```

### 1. Issue first

No code without a GitHub Issue. Before starting work, find or create an issue describing the change, with acceptance criteria and a definition of done. Use the issue templates.

### 2. Implementation Plan before code

Before writing any code, post an `## 🧭 Implementation Plan` comment on the issue covering:

- **Approach** — the strategy in 2–4 sentences; the key design decision and the alternative you rejected.
- **Files** — each file you'll create or modify, and what changes in each.
- **Tests** — the tests you'll add and the edge cases they pin down. For a bug, the first test is a failing reproduction.
- **Acceptance criteria** — map each criterion from the issue to how the plan satisfies it.
- **Risks / open questions** — anything needing a maintainer's call before you build.

Scale depth to the size of the change: a one-line fix gets a one-line plan.

### 3. Branch model

| Branch | Purpose | Rules |
|---|---|---|
| `main` | Releases only | Never commit directly. Only `dev → main` release PRs. Tags (`vX.Y.Z`) are cut only from commits on `main`. |
| `dev` | Integration | Never commit directly. Feature PRs target `dev`. |
| `feature/*` | Work | Branch off `dev`, name `<issue#>-<short-slug>` (e.g. `feature/12-pre-break-banner`). Prefix slug with `fix-` for bugs. |

To update a feature branch, **merge `dev` in — never rebase**:

```sh
git fetch origin dev && git merge origin/dev
```

### 4. Commits

Conventional Commits, one logical change per commit:

```
<type>(<scope>): <what changed where> (#N)
```

Types: `feat` · `fix` · `chore` · `refactor` · `test` · `docs` · `style` · `ci`

- Every commit references its issue with `(#N)`.
- Specific subjects — "fix a bug", "updated", "wip" are rejected.
- Non-trivial commits get a body (blank line after subject, explain *why*, wrap at 72).
- Commit at every meaningful working state; if the subject needs "and", split the commit.
- No `Co-Authored-By` trailers.

> Bootstrap exception: the initial repository import predates the issue tracker, so those commits carry no `(#N)`.

### 5. Tests are the spec

- New behavior ships with tests (`swift test`). The `BreakScheduler` state machine is fully covered — keep it that way.
- **Never weaken, skip, or delete a test to make it pass.** A red test means the code is wrong until proven otherwise. Changing a test is allowed only as a deliberate, documented spec change called out in the PR description.

### 6. Pull requests

- Target `dev`. Merge `origin/dev` into your branch immediately before opening the PR.
- Run `swift build && swift test` locally and paste the result into the PR's "How tested" section. CI must also be green.
- Body must contain `Closes #N` (one line per issue closed). `Refs #N` doesn't count.
- Fill the PR template honestly — don't tick boxes that aren't true.
- Feature PRs are **squash-merged** into `dev`; release PRs (`dev → main`) use a **merge commit**.
- A human reviews every PR. Agents never approve or merge.

### 7. Releases (`dev → main`)

1. Update `CHANGELOG.md`: move `[Unreleased]` items into a new dated `vX.Y.Z` section (semver: MAJOR breaking / MINOR feature / PATCH fix).
2. Update the version line in `README.md` to match.
3. Open the `dev → main` PR listing included issues. A release PR without the version bump + changelog entry is incomplete.
4. After merge: tag `vX.Y.Z` on `main` and publish a GitHub Release. Never tag from `dev` or a feature branch, never before the merge.

### 8. House rules (from the PRD)

1. **Health copy is strict.** All user-facing strings live in `Sources/EyeBreak/CopyStrings.swift` and must follow `docs/PRD.md` §2: describe behaviors and comfort, hedge with "may", never claim vision improvement, eye-muscle strengthening, cures, or diagnosis.
2. **Local-only stays local-only.** No network code, no analytics, no telemetry, no dependencies that phone home (currently zero dependencies — keep it that way).
3. Reports that EyeBreak feels annoying or naggy are priority bugs, not feature requests.

### 9. Blocked work

If work stalls for any reason (missing decision, upstream dependency, irresolvable conflict), comment on the issue with a one-line reason and add the `blocked` label. When unblocked, remove the label and note the resolution.
