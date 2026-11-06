---
name: design
description: "Turn a known problem into a proposed design: TL;DR, ELI5, context, architecture, data models, functions, storage, and proposed milestones."
---

# Design

Use when the user explicitly invokes this skill or asks for a design, an
architecture, or "how should we build this". The problem is known well
enough to propose a solution shape. This skill proposes; it does not
create Quests or Tasks on any board, request sign-off, or write code.

Use `dossier` instead when the problem space itself is unknown and no
responsible proposal is possible yet. Use `ask` instead when the goal,
user, or success test is still unclear. Use control's packet flow when a
Milestone is already being built and needs sign-off.

## Procedure

1. Sync first. If the request is dictated or can be read two ways, run
   the iiuc playback and get a go before designing the wrong thing.
2. Research the actual ground: relevant repo files, current data shapes,
   callers, tests, prior designs, and constraints. Never design against
   an imagined codebase.
3. Ask only questions whose answers change the architecture. Everything
   else becomes an explicit assumption or an open question.
4. Draft the design at the scale of the risk. A one-screen change gets a
   one-screen design; the full structure below is for cross-system,
   stateful, or hard-to-reverse work.
5. Propose milestones by shippable output, each with a check that fails
   today. A milestone that cannot be checked is a hope, not a milestone.
6. Run the four red-chair passes below, in order, as you work. Each pass
   can send the design back a stage; a critical finding is fixed in the
   design or stops it, never footnoted and shipped anyway.

## The four red-chair passes (implicit)

Design implicitly performs the red-chair skill four times. The user
does not invoke anything extra; the passes are proportionate, not four
full review documents.

1. **User input.** Attack the request itself before honouring it: is
   this the real ask or a solution in disguise, what did the wording
   assume, whose problem is it, what does success actually look like?
   A flawed input found here invalidates everything downstream, so this
   pass runs first and can end the design with questions.
2. **Problem space.** Attack the framing: is the problem real and
   evidenced, or a symptom; what is the current system actually doing
   and why; what happens if nothing is built; which constraint is truly
   binding? If the problem dissolves under evidence, say so.
3. **Solution.** Attack the proposal: wrong abstraction, hidden
   coupling, unowned state, failure modes, scale and migration cliffs,
   the boring alternative that achieves most of it. Every data model
   and function must survive "what breaks when this is wrong".
4. **Milestones.** Attack the plan: is each milestone a shippable
   output with a failing-now check, are dependencies honest, is the
   first milestone the riskiest useful slice or a comfortable decoy,
   what got smuggled in as scope? Reorder or cut before presenting.

## Output

Reply with the design, or, when the user asks for a file, write
`docs/designs/<slug>.md`:

```text
# <design name>
Status: proposed

TL;DR
<what will exist, and the one decision this design makes>

ELI5
<the whole idea in plain words, repeatable by a smart non-specialist>

## Context            (Observe)
Problem, evidence, current state, constraints, non-goals.

## Design             (Orient, then Decide)
Overview in a short paragraph.
<ASCII diagram when shape, flow, or ownership is the hard part>

### Data models
Entities, fields that matter, invariants, and what is deliberately
not modeled.

### Functions
The load-bearing functions or operations: responsibility, inputs,
outputs, and failure behavior. Signatures where they clarify.

### Storage
Where state lives, what is source of truth, what is derived, backup
and migration shape, and who may write.

### Interfaces and failure modes
External surfaces, trust boundaries, and how each named failure is
detected and contained. Omit any subsection that does not apply.

## Alternatives
What was rejected, why, and what evidence would flip the choice.

## Tests
Acceptance checks, named, each failing now.

## Proposed milestones   (Act)
1. <shippable output> — check: <command or observation> — depends on: <prior milestone or none>
2. ...

## Open questions
Ranked by what their answers would change, each with an owner.

## Red chair record
One short block per pass: user input, problem space, solution,
milestones. Each names the strongest attack made, what changed because
of it (or why the design survived unchanged), and any attack left
unanswered. An unanswered attack is an open question, not a footnote.
```

## Rules

- Data before functions, functions before milestones. A design that
  starts with tasks has skipped the thinking.
- Every load-bearing claim about the current system cites a file,
  symbol, commit, or source. Unverified claims are labeled as such.
- Milestones are proposals in Markdown only. Turning them into a Quest
  is control's `explore` skill, with the CEO's approval.
- When the design is accepted and building starts, the sign-off packet
  supersedes this document. Link it, freeze it, and do not maintain two
  competing designs.
- If research shows the problem is not actually understood, stop and
  say a dossier must come first. A confident design on sand is the most
  expensive output this skill can produce.
- The four passes are not a final polish step. Input and problem-space
  attacks run before designing; solution attacks run on the draft;
  milestone attacks run last. Skipping straight to a finished-looking
  document and retro-writing the record is the failure this prevents.
