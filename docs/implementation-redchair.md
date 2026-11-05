# Implementation red chair: templating, scaffolder, linter

Status: decided for v1. This document records the adversarial pass over the
implementation approach before the toolchain hardens.

## Proposal under attack

Author each yap skill once as a templated source, render harness-compatible
Markdown for pi, Claude, Codex, and Muse, and ship a scaffolder plus a linter
around the sources. pi is the first tested harness; Codex and Muse joined
it in the 2026-11-05 battle test, Claude remains render-only
(docs/harness-tests.md).

## Attacks and verdicts

### 1. Templating turns skills into programs

Full Jinja can hide behavior in loops, macros, and filters until a skill is
code with worse tooling than code. bp2's typed factory is the warning.
Jingoo (the OCaml Jinja clone) would import that whole surface for five
variables.

Verdict: survive with a narrower contract than any off-the-shelf engine.
`lib/template.ml` implements only variable substitution and nestable
`if ==` / `if !=` conditionals over the harness context, strict on unknown
names. No filters, macros, or loops exist to abuse. The linter counts
harness conditionals and warns above four per skill.

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

### 6. Which language builds the toolchain

Python plus Jinja was the first working build (one local commit, never
pushed). It was challenged on review: bp3's preference is OCaml for types
and build speed, bp1's Python test pain is on record, and a second
language for a five-variable template engine is a cost with no buyer.

Verdict: OCaml, via dune. The toolchain builds to one `yap` executable
(`dune build`, `dune exec yap -- ...`), depends only on cmdliner and
yojson beyond the standard library, and its tests run under `dune test`.
A committed pre-commit hook (`.githooks/pre-commit`) runs build,
ocamlformat check, `yap check`, and `dune test`, so the linter cannot be
quietly skipped at commit time.

### 7. Hand-edits to installed skills get clobbered

Verdict: the installer records SHA-256 hashes in a lock file beside the
installed skills. An existing destination whose hash differs from the lock
is refused unless `--force` is explicit. First install over a foreign file
of the same name is also refused.

## Locked v1 shape

- Jinja-shaped sources at `skills/<id>/SKILL.md.j2`; plain Markdown out,
  rendered by the in-repo mini engine, not Jinja or Jingoo.
- `harnesses.json` is the only harness knowledge; pi tested first.
- One OCaml CLI, `yap`: `check`, `render`, `install`, `new`, `list`.
- `dune build @render` is the canonical check: it lints and renders every
  harness into `_build/default/rendered/<harness>/`, and the pre-commit
  hook runs it. Rendered pi output includes a prompt-template `.md` per
  skill, which is how pi gets exact `/<skill>` commands while the skill
  itself stays a portable `SKILL.md`.
- Install scope is explicit: `install -p/--project` or
  `install -g/--global`, never both, never implicit.
- Harness selection is data plus one convention: `--harness` flags
  (comma-separated or repeated), else `$HARNESS` (comma-separated), else
  pi. Two selected harnesses sharing a skills root in one scope are
  refused up front.
- `dune test` covers rendering, lint, scaffold, and install against
  temporary directories. Tests are committed with the toolchain.
- Only `iiuc` is implemented in v0.1.0. The designed roster stays designed
  until each skill passes the add-skill gates.
