---
name: red-ink
description: "Present an existing design back to its owner in rounds until they say they are happy: copy the design first (original untouched), walk output first, then system inputs, then internals (data, state, functions, names, concepts); every round is Observe (teach) -> Orient (what matters) -> Decide (one detailed question, the owner's call) -> Act (one settled edit to the copy), closing with an IIUC playback and, at the end, a decision record plus proposed experiments. Use for Socratic design review of an existing artifact. Not for one-shot adversarial review (red-chair), authoring a new design (design), or interviewing an unclear request (ask, grill)."
---

# Red ink

```text
existing artifact
    |
    +-- copy --> working copy        (original stays untouched)
                     |
    walk:  output -> inputs -> data -> state -> fn -> names -> concepts
                     |
    per slice: Observe -> Orient -> Decide -> Act -> IIUC
                     |
    owner: "happy / settle"
                     v
    decision record + proposed experiments
```

```python
def red_ink(artifact, expert=None):
    copy = duplicate(artifact)           # original never edited
    for slice in [output, inputs, data, state, fn, names, concepts]:
        teach(slice)                     # Observe
        orient(slice)                    # the 2-4 things that matter
        decision = ask_one(owner)        # Decide: options + recommendation
        apply_one_edit(copy, decision)   # Act
        playback()                       # IIUC: settled / changed / open
        if owner.happy:
            break
    return exit_pack(decisions, open_questions, experiments)
```

## Context

Reading map for this skill: prose carries context, why, and how
we got here. Diagrams, pseudocode, and tables carry what we do.

Designs die in review when the owner gets the whole blob at
once: the read turns into a rubber stamp, and the objections
surface mid-build, priced as migrations. Red ink slows the
review down to one slice at a time so each decision lands
while changing it still costs a sentence.

How we get there shapes the walk below. Output goes first
because a design that emits the wrong thing earns no points
for elegant internals. One question per round keeps decisions
from smearing into each other. The original stays untouched
because a review that rewrites its own evidence can never be
re-run. The IIUC closes each round because the owner's
cheapest correction arrives right after the read, not three
slices later.

## When this fires

| Case | Fire |
|---|---|
| `/red-ink`, “walk me through this design” | this skill |
| one-shot adversarial pass, no loop | `red-chair` |
| written four-pass review the owner reads alone | `red-chair-design` |
| no design exists yet | `design` |
| the request itself is unclear | `ask` / `grill` |

## The walk

Output first. A design whose output is wrong earns no internals
discussion.

| Slice | Question it answers |
|---|---|
| Output | what it emits: calls, verdict shapes, error codes, exits |
| Inputs | what it takes in: args, flags, env, config, files |
| Internals: data | shapes and schemas |
| Internals: state | lifecycle, stored vs derived |
| Internals: functions | edges, who does what |
| Internals: names | every variable and term, one line each |
| Internals: concepts | the coined vocabulary a newcomer must learn |

Domain experts supply slice definitions where one exists
(see Expert index).

## Round shape (one slice per round)

| Phase | Carries |
|---|---|
| Observe | the lay of the land, TL;DR first, cited from the artifact |
| Orient | the 2-4 things that matter, tensions, the turning question |
| Decide | exactly one detailed question: options + recommended answer. The owner calls it |
| Act | one edit to the working copy applying that one decision; “no edit” when the call was keep-as-is |
| IIUC | playback: settled, changed, still open |

```text
Observe -> Orient -> Decide -> Act -> IIUC -> next slice
              ^                                  |
              +---- owner corrects the read -----+
```

## Cases

| Situation | Move |
|---|---|
| Decide question still unanswered | stay on the slice |
| owner defers a question | record it under Deliberately open, with an owner; move on only when the owner says so |
| later decision reopens a settled slice | re-present that slice; the rest stay settled |
| a full pass completes | ask: another pass, or settle |
| owner says happy / settle | produce the exit pack, in order |
| owner adopts the copy | move the working copy over the original (`mv`, never a merge), set the lifecycle status the owner names; the old original survives in git history, and a recovery snapshot is saved first when the tooling offers one |

## Exit pack

| # | Item | Contents |
|---|---|---|
| 1 | Decision record | every settled decision, one line, before -> after, with its round |
| 2 | Inputs behind them | Observed (final lay of the land), Oriented (priorities) |
| 3 | Paths | original (untouched) + working copy |
| 4 | Deliberately open | deferred questions, each with an owner |
| 5 | Final IIUC | the settled design in one read |
| 6 | Proposed experiments | only when implementation follows; each exp written per Experiments below |

## Experiments

Proposed experiments, and any exp walked during a pass, are
presented in this shape, in this order:

```text
TL;DR -> demo -> diagram (ascii) -> pseudocode (python)
      -> tables -> acceptance test (goal block) -> prose
prose = context, why, how we got here, edge cases
code  = what we're gonna do
```

| Part | Carries |
|---|---|
| Demo | up front: one worked trace, labeled `observed` or `design trace` |
| ASCII diagram | the flow at a glance: inputs, outputs, where it can stop |
| Python pseudocode | the mechanism in one readable pass |
| Tables | intent, lane, output, acceptance that fails today, depends-on; cases and gates |
| Acceptance test | one goal-shaped block: `objective`, `prove by`, `done when` (the exact observation) |
| Prose | context, why the exp exists, how we got here, edge cases |

An exp whose acceptance passes today gets sent back: a check
that cannot fail is a hope, and hopes do not gate builds. An
exp with no demo and no runnable goal block is unfinished
spec. The design file itself gets the same treatment at its
scale: a Demos section up front, traces honestly labeled.

## Rules

| Rule | Why it exists |
|---|---|
| copy first; name both paths in round one | the original never takes an edit |
| one question per round | a round with no Decide produced nothing |
| owner is the gate | the loop ends on the owner's word |
| decisions recorded in the owner's words | editorials belong in Orient, before the call |
| stateless skill | the working copy + transcript carry all memory |

Terms sync with code and data: during names and concepts rounds,
check every term against the identifiers it becomes (CLI verbs
and flags, states, ledger fields, files, branches, types,
variants). Code or data already has a spelling -> the design
adopts it. Owner renames -> the Act applies the new spelling
across the working copy and records the matching code/data
rename as owed in the same change. Two spellings for one concept
means the decision is still open.

## Expert index

| Domain | Lens |
|---|---|
| CLI designs | `expert-cli` (calls/verdicts/error codes; args/flags/env; data/state/fn/names/concepts) |

New experts enter through the add-skill gates, one at a time,
and join this index as a named edit.
