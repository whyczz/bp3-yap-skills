---
name: red-chair-design
description: "Run a four-pass read-only review of an existing design artifact (quest, exp, design doc, report): coherence, implementation confidence, ecosystem fit against a named referent, and a language cut list. Not for diffs (use red-chair), authoring (use design), or wording fixes."
---

# Red chair design

Use when a human invokes this skill by name or asks for the bigger
multi-pass review of an existing design artifact: a quest, exp, design
doc, or report they want judged before building from it. This is the
deep counterpart to `red-chair`'s single lens. It never edits the
artifact; the language pass produces a cut list, and edits are a
separate user-approved step.

## Pass 0 — Scope gate

Name the target and read it fully, including linked docs and the code
it cites. Settle three things before any pass; if one is missing, ask
with a recommended answer for each, in one short round:

- **Bar:** coherence-only, or implementable by a stranger (could a
  builder execute this packet without inventing decisions)?
- **Ecosystem referent:** "in the context of X" — a named quest,
  project, or downstream consumer. Required for Pass 3; without one,
  ask, or mark Pass 3 skipped with the reason.
- **Deliverable:** findings plus cut list. Never edits.

## Pass 1 — Coherence

Attack the artifact as a document: Does it contradict itself? Could a
stranger state its goal and success test in one sentence each? Does
every section earn its place, or repeat another? Is anything claimed
twice with different words (status, acceptance, decisions)? Exit when
every internal contradiction is cited, or none were found and the
strongest one you tried is named.

## Pass 2 — Implementation confidence

Verify every load-bearing claim against code, tests, or a command;
label the rest inference. Hunt: deferred decisions the builder would
have to invent (schema, ownership, serialization, bounds), missing
operation homes (who runs this, in which process), edge cases stated
as prose but not pinned (empty, duplicate, crash-between-steps, stale
retry), and numbers left as "bounded" without a value. Under an
implementable bar, a deferral is a finding, not a footnote.

## Pass 3 — Ecosystem fit

Test the design only against the referent named in Pass 0: What does
it break, duplicate, or strand downstream? What is the onboarding or
migration path from here to that context, and is it gated on a toy or
demo before the real target? What would that context's first user hit
on day one that this design does not mention? Generic advice means
this pass failed; rerun it against the referent or report it skipped.

## Pass 4 — Language

Sharpen and shorten, on paper only. Produce a cut list: duplicated
clauses (said in prose and again in acceptance), dead history that
lives in git or a linked record, restated decisions kept in two
documents, hedges repeated instead of fixed. Give file/line refs, an
estimated line or word reduction, and at most one example rewrite per
pattern. Do not apply any of it.

## Output

```text
TL;DR: <ship, fix first, or rethink, in one line>

Pass 1 — Coherence
1. [critical|major|minor] <claim> — <evidence>
   Why it matters: <consequence>
   Next step: <smallest concrete action>

Pass 2 — Implementation confidence
...

Pass 3 — Ecosystem fit (<referent, or skipped: reason>)
...

Pass 4 — Language (cut list)
- <file:lines> — <what to cut or merge> — saves ~N lines

What would change my mind: <evidence that would flip the verdict>
```

## Rules

- Read-only. No edits, no commits, no fixes applied "while you're here".
- Severity is about consequence, not taste.
- Praise is not a finding. Neither is a restatement of the plan.
- A claim you checked is fact; a claim you did not is labeled inference.
- If the artifact survives a pass, say so and name the strongest attack
  it withstood. A chair that always condemns is noise.
