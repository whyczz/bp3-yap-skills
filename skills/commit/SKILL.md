---
name: commit
description: "Draft a git commit message in the bp3 format: TL;DR, a human section (ELI5, problem, solution), and a structured section for LLMs."
---

# Commit format

Use when the user explicitly invokes this skill, asks for a commit message,
or asks you to commit work. Inspect the actual diff first (`git status`,
`git diff`, `git diff --cached`, and the branch's recent commits for house
style). Never write the message from the task description alone.

Default behavior: draft the message and show it. Create or amend the
commit only when the user's invocation explicitly asks for that
("commit this", "amend", or the like). Formatting is the skill; landing
is not.

## Branch and landing policy

- The user's default/integration branch is **`master`**, not `main`. Use
  `master` in plans, commands, and promotion language; never silently substitute
  `main` because it is a tool's or hosting provider's default.
- Inspect the actual local branches, remote default, and upstream before any
  commit or push. If a repository only has `main`, report the mismatch; rename
  it only with explicit user authorization. Preserve history, establish and
  verify remote `master` as the default before removing the old branch name,
  and stop if the remote moved unexpectedly.
- This preference does **not** mean every commit belongs on `master`. Keep
  Quest/feature work on its named branch until the user authorizes integration.
  Honor split instructions such as “skill fix on master and pushed; Exp 1 on
  the Quest branch” with separate commits and separately scoped pushes.
- A commit request does not authorize a merge or push. Do not push all branches,
  promote Quest work, or force-update history to satisfy the branch preference.

## The format

```text
<type>(<scope>): <imperative summary, no period, aim under 50 chars>

TL;DR
<one or two sentences: what changed and why it matters>

For humans

ELI5
<the change in plain words a smart non-specialist could repeat back>

Problem
<context: what was wrong, missing, or decided, and the pressure behind it>

Solution
<how it works now. Name classes, data structures, and functions when
they changed. Include a small ASCII diagram only when data or control
flow changed shape; twelve lines at most, or omit it>

For LLMs

Changed: <path or area> — <effect>
Contracts: <types, schemas, APIs, invariants added or changed; "none" if none>
Verification: <exact commands run and their outcomes; say "not run" plainly>
Risk: <breaking changes, migrations, follow-ups; "none known" if none>
```

Rules:

- Subject uses a conventional type (`feat`, `fix`, `refactor`, `test`,
  `docs`, `chore`, `style`, `perf`, `ci`) and a scope derived from the
  diff or branch, lowercase kebab-case. Imperative mood.
- TL;DR is not the subject restated. It carries the why.
- ELI5 has no jargon that the Problem section has not already introduced.
- Solution names identifiers exactly as they appear in the diff. Do not
  describe classes or structures that were not touched.
- The LLM section is facts, not narrative: paths, identifiers, commands,
  outcomes. Anything not verified is marked as such. An agent reading
  this commit later should be able to reconstruct what changed without
  opening the diff.
- Keep standard git trailers (`Fixes-lesson:`, `Refs:`, `Co-authored-by:`)
  after the LLM section when they apply. No AI attribution unless the
  repo's own conventions ask for it.
- If the diff is really two changes, say so and draft two messages.
  One commit, one idea; a format cannot fix a mixed diff.
- Match the repo's existing commit style when it conflicts with this
  format in the small (scope words, trailer habits). The TL;DR /
  For humans / For LLMs structure is the non-negotiable part.
