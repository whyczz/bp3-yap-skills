---
name: auto-red-ink
description: "Headless flavor of red-ink for when the owner is absent: walk an existing design output-first, then inputs, then internals (data, state, functions, names, concepts), shadow-boxing each round's Decide step against expert lenses; produce the edited design copy, a decision record of what was settled and how, and the questions that could not be settled without the owner. Use when a human asks for a design to be worked out without them present. Not for interactive review (red-ink), one-shot attack (red-chair), or authoring from a blank problem (design)."
---

# Auto red ink

Use when a human invokes this skill by name
(`/auto-red-ink`) or asks for a design to be figured out
while they are away: "shadow-box this and come back with a
design." This is `red-ink` with the owner absent: same walk,
same OODA rounds, but the Decide step is played against
expert lenses instead of a person. It returns a design the
owner can red-ink later, not a verdict they must accept.

Use `red-ink` instead whenever the owner is present — a
shadow decision is always weaker than a real one. Use
`design` instead when no design artifact exists yet.

## Procedure

1. Copy the design first; the original is never edited.
   Name both paths in the output.
2. Match the domain's expert lens from the index below and
   load it. With no matching expert, use the generic
   red-ink slices (output, inputs, data, state, fn, names,
   concepts) and say the walk was lens-less.
3. Walk the slices in order, one round each, in OODA form:
   - Observe: teach the slice from the artifact.
   - Orient: what matters here, per the lens's rules.
   - Decide (shadow): argue both sides in the lens's terms.
     Settle only when the lens or the artifact's own
     evidence forces one reading; record the deciding
     evidence. When evidence ties, do not settle — move
     the question to Unsettled and design around it the
     least-committal way.
   - Act: one edit to the copy per settled shadow decision.
4. Close with the output below.

## Output

- Original path (untouched) and working-copy path.
- Decision record: each shadow decision, the evidence or
  lens rule that forced it, and before -> after on the copy.
- Unsettled: every question that needs the owner, each with
  the options considered and what each would change. This
  list is the handoff to a later `/red-ink` session; an
  empty list claimed without a full walk is a failure.
- Proposed experiments, only when the design implies
  implementation: intent, inspectable output, acceptance
  that fails today, depends-on.

## Rules

- Never present a shadow decision as the owner's decision.
  The copy is a draft until the owner signs it, ideally in
  a `/red-ink` session.
- Least-committal under uncertainty: when a question is
  unsettled, choose the reading that is cheapest to reverse
  and say so.
- Stateless: no state between sessions; the copy, the
  decision record, and the unsettled list are the output.

## Expert index

- CLI designs: `expert-cli`.

New experts enter through the add-skill gates and are added
to this index and to `red-ink`'s as one named edit.
