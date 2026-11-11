---
name: red-ink
description: "Present an existing design back to its owner in rounds until they say they are happy: copy the design first (original untouched), walk output first, then system inputs, then internals (data, state, functions, names, concepts); every round is Observe (teach) -> Orient (what matters) -> Decide (one detailed question, the owner's call) -> Act (one settled edit to the copy), closing with an IIUC playback and, at the end, a decision record plus proposed experiments. Use for Socratic design review of an existing artifact. Not for one-shot adversarial review (red-chair), authoring a new design (design), or interviewing an unclear request (ask, grill)."
---

# Red ink

Use when a human invokes this skill by name (`/red-ink`) or asks
to be walked through an existing design until they are happy
with it: a quest, a design doc, an API proposal. The product is
the owner's settled judgment, recorded as decisions and applied
to a working copy one edit at a time. The original is never
edited.

Use `red-chair` instead for a one-shot adversarial pass with no
loop. Use `design` instead when no design exists yet to
present. Use `ask` or `grill` instead when the request itself
is unclear and there is no artifact. Use `red-chair-design`
instead for a four-pass written review the owner reads alone.

## The walk

Present in lens order. Output first, always: a design whose
output is wrong does not earn an internals discussion. Each
slice below is one round:

1. Output — what the system emits and the decisions it
   serves: calls, verdict shapes, error codes, exit behavior,
   or the domain equivalent from the matching expert lens.
2. Inputs — what the system takes in: args, flags, env,
   config, files, requests.
3. Internals, top-down: design/data (shapes, schemas),
   design/state (lifecycle, derived vs stored), design/fn
   (functions, edges), variable names (each, one line),
   concepts (the coined vocabulary a newcomer must learn).

When the design's domain has an expert skill (see the expert
index), its lens supplies the slice definitions and rules for
the walk. Without an expert, use the generic slices above.

## Rounds (OODA)

Every round produces exactly this shape:

- Observe (input): teach the slice — the lay of the land, in
  plain words, TL;DR first. Cite the artifact; never present
  from memory of how such systems usually work.
- Orient (input): what is important at this slice — the two
  to four things that matter, the tensions, the question this
  round turns on.
- Decide (output): exactly one detailed question — the
  highest-leverage open decision at this slice — with options
  and a recommended answer. Wait for the owner's call. Record
  the decision in the owner's words.
- Act: apply that one settled decision as one edit to the
  working copy, or record "no edit" when the decision was to
  keep the design as-is. Never batch unmade decisions into an
  edit; never edit the original.
- IIUC: close the round by playing back where the design
  space stands — settled, changed, still open — for the
  owner to correct.

After each full pass through the lens (output through
concepts), ask: another pass, or settle? Do not advance a
slice while its Decide question is unanswered, and do not
re-present a settled slice unless a later decision changed
it.

## Exit (owner says they are happy)

Present, in this order:

1. Decision record: every settled decision, one line each,
   with before -> after as applied on the copy, and the
   round that decided it.
2. The inputs that produced them: Observed (the lay of the
   land as taught, final form) and Oriented (what mattered,
   in priority order).
3. Original path (untouched) and working-copy path.
4. Deliberately open: questions the owner deferred, each with
   an owner. Never drop a question silently; a deferred
   question is a recorded decision to defer.
5. Final IIUC of the settled design.
6. Proposed experiments — only when the design implies
   implementation: Exp N with intent, inspectable output,
   acceptance that fails today, and depends-on. No
   implementation implied, no experiments; never pad.

## Rules

- Copy first: make the working copy before the first edit
  and name both paths when presenting the first round.
- One question per round. Detailed, with options and a
  recommendation; a round with no Decide produced nothing.
- The owner is the gate. The loop ends when they say they
  are happy, or at the full-pass checkpoint when they say
  settle — never when the questions run out on their own.
- Decisions are recorded in the owner's words; editorials
  about why they are wrong belong in Orient, before the
  call, never as a footnote after it.
- Stateless: this skill holds no state between sessions.
  The working copy and the decision record in the transcript
  are the whole memory.

## Expert index

Lenses live in standalone expert skills; match the design's
domain before the first round and load that lens:

- CLI designs: `expert-cli` (calls/verdicts/error codes;
  args/flags/env; data/state/fn/names/concepts).

New experts enter through the add-skill gates, one at a
time, and are added to this index as a named edit.
