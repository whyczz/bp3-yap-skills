---
name: expert-cli
description: "CLI design lens for red-ink and auto-red-ink walks, or standalone when a human asks for CLI design rules: public output (calls, verdicts, error codes, exit behavior), system inputs (args, flags, env, config files), and internals (data shapes, state, functions and edges, variable names, concepts). Use when a design under review is a command-line interface. Not for building a CLI (implementation), naming alone (naming in bp3), or GUI/API design."
---

# Expert: CLI

The lens a CLI design is walked against, slice by slice.
Rules marked (session) were mined from a real design session
and state where they came from; unmarked rules are the
lens's standing defaults.

## Output (design the output first)

- Calls: the verb surface. One noun door, verbs after the
  name (`tool <thing> <verb>`); one concept, one spelling,
  everywhere — files, CLI, docs, chat.
- Verdicts: machine-readable output on stdout (JSON where a
  program consumes it), human text on stderr. Every read and
  every write returns the same verdict shape; a write's
  verdict is the read that would follow it.
- Refusals are output too: a refused call returns a named
  error code, the facts needed to act (e.g. the new expected
  value), and an exit code class that separates retryable
  from terminal from usage errors. A driver must never parse
  prose to tell "go again" from "stop forever." (session:
  landing loop vs stderr strings)
- Exit behavior is contract: 0 success; distinct non-zero
  classes for retryable refusal, terminal refusal, and
  usage/not-found. Document them where the calls are
  documented.

## Inputs

- Args and flags: judgment inputs carry explicit flags with
  named values (--verdict, --reason); positionals are for
  identity (which thing), flags for judgment (what about it).
- Required judgment inputs fail loud: a missing --reason or
  --verdict is a usage error, never a silent default.
- Env and config: state which inputs come from the
  environment (roots, binary paths), which from files, and
  which file wins when they disagree. An authored plan file
  is never rewritten by a move; generated state is written
  only by the tool. (session: fsm.yaml vs QUEST.md sync)
- Reserved words: names a user can coin must not collide
  with the verb surface at the same argv position; reserve
  and refuse at creation time.

## Internals

- design/data: the smallest record that carries the state
  (e.g. stage, commit, cycle, seq); derived views are caches
  rebuilt from the truth, never a second truth.
- design/state: name the lifecycle, the legal moves per
  state in one place, and which transitions are terminal.
  A move with no legal successor state for a legitimate
  need (e.g. a rebased commit re-entering review) is a
  missing edge, not a user error. (session: ready-state
  re-entry)
- design/fn: separate telling ("what is true?"), judging
  ("what should this become?"), and finalizing ("make this
  atomic and record it"). Atomic compare-and-swap moves
  (update only if still the expected value) belong to the
  binary/tool; choreography around them (rebase, cleanup)
  belongs to the driver or skill. A tool that shells out to
  git states which calls it makes and why each is safe.
- Names: one concept, one word, one spelling everywhere;
  a newcomer-guessable word beats a clever one; verdict
  words must not collide with state words they route to.
  (session: fix_first -> needs_fix) Renames are one change
  across binary, tests, docs, and skills, or they did not
  happen.
- Concepts: the coined vocabulary is listed with one-line
  meanings inside the design itself (a Concepts header), so
  the walk can attack names before they become paths and
  ledger values.

## Walk order

Output, inputs, then internals in the order above — the
order red-ink presents. A CLI design that starts at
internals has skipped the only part its users ever see.
