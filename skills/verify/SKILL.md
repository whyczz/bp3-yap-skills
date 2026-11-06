---
name: verify
description: "Verify a claim or a finished change by running the real checks now and reporting exact outputs before anyone says done."
---

# Verify

Use when the user explicitly invokes this skill, asks "does it work", or
before any claim that work is complete, fixed, or passing. Verification
is fresh evidence, produced in this session, not remembered green.

## Procedure

1. List the claims to check, one per line, taken from the task, the
   diff, or the user's message. A claim you cannot state cannot be
   verified.
2. For each claim, pick the check that would fail if the claim were
   false: the named acceptance check, the test suite for the touched
   area, the built artifact actually run, the rendered page actually
   loaded. Prefer the repo's own declared gate (Makefile, CI config,
   package scripts) over an invented command.
3. Run the checks now. Read the real output, including counts and
   failures, not just the exit code.
4. Map every claim to its evidence. Anything not run is reported as
   unchecked with the reason, never folded into a pass.

## Output

```text
Claims checked:
- <claim> — <command> — <real outcome, with the decisive output>

Unchecked:
- <claim> — <why it was not run>

Verdict: <done, not done, or done-except, matching the evidence above>
```

## Rules

- No hedging words as evidence: "should pass", "looks right", and
  "previously green" are not verification.
- A failing check is reported as failing, with output. Do not narrow
  the run, skip the test, or edit the check to reach green; that is a
  new task, named as such.
- If the environment blocks a check (missing service, no credentials),
  say which claim that leaves unproven. The verdict shrinks to fit.
- Re-running the same unchanged check to collect a second green proves
  nothing. Change something or test something else.
