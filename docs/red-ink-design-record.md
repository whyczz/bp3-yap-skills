# red-ink family — add-skill design record

Date: 2026-11-09. Skills: `red-ink`, `auto-red-ink`,
`expert-cli`. Origin: a bp3 CLI design session where
convergence required, in order: teach (TL;DR), public output
(API/verdicts), inputs, internals (data, state, functions),
variable names, concepts — each layer driven by hand.

## Gate 1 — Clarify

Job: present an existing design in rounds until the owner is
happy; copy-first edits, one decision at a time; close with a
decision record and proposed experiments.
Invoker: a human, by name (`/red-ink`). Exit shape, lens
order, OODA naming (Observe/Orient inputs, Decide the only
output), standalone experts + shared index, and one-quest-at-
a-time scope were all settled by the owner in session, one
question at a time, and confirmed by IIUC playback.

Examples (+): `/red-ink this quest`; "red-ink the land
design before I sign it"; `/red-ink docs/design.md — output
first`.
Near-misses (−): "fix the typo in this design"; `/red-chair
this plan`; "write me a design for X".

## Gate 2 — Prior art (roster)

- `grill`: one-question interviews into durable docs for
  unclear requests. Not absorbed: no design presentation, no
  lens walk, no copy semantics. Sharpest boundary; handled
  in descriptions.
- `red-chair` / `red-chair-design`: one-shot, read-only.
  Not absorbed: no loop, no edits.
- `design`: one-pass authoring with Observe/Orient/Act
  sections. Not absorbed: red-ink reviews an existing
  artifact iteratively, from any source.
- `ask`, `iiuc`, `teach`: components, composed per round.
bp2/bp1 catalogs and internet: unchecked this run.

## Gate 3 — Log mining

Unchecked (no archive miner invoked). Informal evidence:
the originating session (n=1) with five manual layer
corrections. Recorded as such, never as counts.

## Gate 4 — Red chair on the proposal

Verdict: proceed, with mitigations baked in: trigger
fingerprints in descriptions ("until they are happy",
copy-first, output-first) against the grill/red-chair seam;
a full-lens-pass checkpoint against unbounded rounds; one
slice per round against context tax. Stateless test passes:
the working copy is a file, no board/queue/hook/daemon.

## Gate 5 — Adversarial trigger tests

Draft descriptions classified by a fresh scratch session,
12 utterances: 3 examples + "keep presenting until I'm
happy" -> red-ink; headless request -> auto-red-ink; CLI
rules question -> expert-cli; near-misses -> NONE,
red-chair (x2, incl. "tell me what's wrong, don't change
anything"), design, ask, grill. 12/12 correct, both hostile
cases (read-only review wearing red-ink words; decision
interview wearing review words) included. Transcript in the
originating Muse session, 2026-11-09.

## Gate 6 — Write

Scaffolded with `scripts/yap new`; TODOs replaced; README
roster rows added; `make check` green (yap check ok,
test_yap 345 assertions). Not installed to any harness yet
and not committed; the owner signs by installing.
