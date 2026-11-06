---
name: add-skill
description: "Author one new yap skill through its gates: clarify, search prior art, optional log mining, red chair, and adversarial trigger tests before writing."
---

# Add skill

Use when the user explicitly invokes this skill or asks to add a skill to
bp3-yap-skills. This skill is the roster's immune system. It writes
nothing until every gate passes; failing a gate produces a report, not
a directory. Absorb-or-reject is the common outcome.

## Gates, in order

1. Clarify. Use the iiuc and ask skills. The candidate gets: a
   one-sentence job, who invokes it (a human, by name, or it does not
   belong in this repo), three example invocations, and three near-miss
   invocations that must not trigger it. No examples, no further gates.
   A candidate with no papercut, session, or repeated correction behind
   it stops here.
2. Search prior art. Use the search skill, in order: this roster, bp2's
   catalog, bp1's workflow skills, then the internet (Superpowers,
   Compound Engineering, gstack, Anthropic's skills, and a web search
   for the job in words). Output: a table of existing skill, overlap,
   and absorb-or-not. If an existing skill absorbs it with a section
   added, the result is that edit, not a new skill.
3. Mine the logs (optional). When an archive miner is available, ask
   it for sessions for and against the candidate: repeated friction it
   would have prevented, against absorption by an existing skill,
   trigger misfires, or one-off occurrences. Every claim needs session
   links and counts. No archive yet means this gate is `unchecked`,
   recorded as such, never as support and never as a blocker.
4. Red chair. A read-only adversarial pass over the proposal: overlap
   stated plainly; the stateless test (any Board, queue, hook, or daemon
   need routes it to control, worker, or archive, by name); failure
   modes; context tax on every future session; name collisions across
   harnesses. Verdict: absorb, reject, or proceed. The red chair must
   address the mined evidence line by line when it exists.
5. Adversarial checks. Test the trigger before writing: the three
   examples must invoke the candidate, the three near-misses must not,
   plus two hostile cases (keyword match that wants a different skill;
   stateful work wearing yap words). Run against a draft in a scratch
   session and keep the transcripts for the report.
6. Write, only now. Scaffold with `./scripts/yap new <id>`, replace every TODO
   (the linter rejects TODOs), add the README roster row, and pass
   `make check`. Commit the design record beside
   the change: search table, mined evidence where it exists, chair
   verdict, and test transcripts.

## Rules

- The user is the final gate, the way they sign packets. An overruled
  chair verdict is recorded with their reason.
- A skill is one job, invocable by a human by name, producing one
  specified output shape. Anything else is a worker pack or a control
  skill wearing yap clothes; route it, do not force it in.
- Never edit an existing skill silently as a side effect. Absorption is
  a named edit the user sees.
