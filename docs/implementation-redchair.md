# Implementation red chair: templating, scaffolder, linter

Status: decided for v1. This document records the adversarial pass over the
implementation approach before the toolchain hardens.

## Proposal under attack

Author each yap skill once as a templated source, render harness-compatible
Markdown for pi, Claude, Codex, and Muse, and ship a scaffolder plus a linter
around the sources. pi is the first tested harness.

## Attacks and verdicts

### 1. Jinja turns skills into programs

Full Jinja can hide behavior in loops, macros, and filters until a skill is
code with worse tooling than code. bp2's typed factory is the warning.

Verdict: survive with a narrow contract. Templates receive only `skill_id`,
`version`, `invocation`, and the `harness` row. No custom filters or macros.
Conditionals are allowed only for a rendered difference a test names. The
linter counts harness conditionals and warns above four per skill.

### 2. Four rendered copies duplicate one document

Most harness differences are the install directory and invocation spelling,
not the skill body. Rendering everything invites drift and fake precision
about untested harnesses.

Verdict: the source is canonical; rendered files are derived and never
committed from `generated/`. The harness matrix is data. pi is marked
`tested = true`; other rows render but are not claimed as verified until a
real load test exists.

### 3. pi might need extensions instead

pi extensions are TypeScript runtime code. They can intercept events and
block tools, which is control machinery. Yap skills need the model to think
in a specified shape and a human to judge the result.

Verdict: no extensions in this repo. `/iiuc` remains a skill first by
explicit decision (2026-11-05). An automatic pi input interceptor, if ever
built, belongs in control and wraps this skill; it does not replace it.

### 4. The scaffolder becomes an approval bypass

A generator that creates a plausible directory makes unreviewed skills feel
official.

Verdict: `yap new` is mechanical only. It writes TODO markers that the linter
rejects, so a scaffold cannot pass `yap check` until a human fills the job,
examples, near-misses, and rules. The add-skill gates remain the approval
path; scaffolding is not approval.

### 5. The linter becomes a style police toy

A linter that checks everything checks nothing important and gets bypassed.

Verdict: v1 checks only contract failures: valid skill id, exactly one
source per skill, frontmatter name matches directory, description present,
renders under StrictUndefined for every harness, no unresolved template
markers, no TODO scaffolding left, README names every implemented skill,
and a 500-line ceiling. Taste stays in review.

### 6. Python is the wrong stack for bp3

bp3's control plane is planned in OCaml, and bp1's Python test pain is real.

Verdict: accepted for authoring only. This repo's deliverable is Markdown;
Python plus Jinja2 is the smallest honest templating tool, runs through uv,
and is absent from installed skills and from every runtime path. If the
renderer ever needs to run inside an agent loop, this decision gets its own
packet and a rewrite is on the table.

### 7. Hand-edits to installed skills get clobbered

Verdict: the installer records SHA-256 hashes in a lock file beside the
installed skills. An existing destination whose hash differs from the lock
is refused unless `--force` is explicit. First install over a foreign file
of the same name is also refused.

## Locked v1 shape

- Jinja2 sources at `skills/<id>/SKILL.md.j2`; plain Markdown out.
- `harnesses.toml` is the only harness knowledge; pi tested first.
- One CLI: `check`, `render`, `install`, `new`, `list`.
- Unit tests use temporary directories and the real Jinja renderer. They are
  committed with the toolchain, not left as probes.
- Only `iiuc` is implemented in v0.1.0. The designed roster stays designed
  until each skill passes the add-skill gates.
