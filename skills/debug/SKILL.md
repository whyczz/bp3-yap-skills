---
name: debug
description: "Debug systematically: reproduce, isolate, and prove a root cause before proposing any fix."
---

# Debug

Use when the user explicitly invokes this skill, reports a bug, a failing
test, or "it stopped working". Iron law: no fix proposal before root
cause evidence. A plausible story is not a root cause.

## Procedure

1. Reproduce. Get the failure to happen on demand: exact command, input,
   and output. No reproduction, no debugging; say what you tried.
2. Shrink it. Smallest input, smallest scope, last known good state
   (bisect history when the regression window is the mystery).
3. Form one hypothesis at a time, stated so it can be wrong:
   "X happens because Y; if so, Z will show it." Test the cheapest
   prediction first.
4. Read the code the failure actually flows through. Form hypotheses
   from evidence, not from what the module is supposed to do.
5. When the cause is proven (the test that shows it, the line that does
   it), state it in one sentence with its evidence. Only then propose
   the smallest fix that addresses the cause, and the check that would
   have caught it.
6. After a fix, re-run the original reproduction and the nearby tests.
   A fix that only passes its own new test is unverified.

## Output

```text
Repro: <command and observed failure>
Root cause: <one sentence, with evidence>
Fix: <smallest change, or "not yet, because <missing evidence>">
Proof: <commands run and outcomes>
```

## Rules

- Three failed hypotheses in a row means the model of the system is
  wrong. Stop, re-read from the failure outward, and say so.
- Never edit the failing check to make it pass and call that a fix.
- Environment is a suspect, not an excuse: versions, dirty tree, stale
  build, and wrong directory get checked, not assumed.
- If the user asked only for diagnosis, stop at root cause. Do not fix
  on momentum.
