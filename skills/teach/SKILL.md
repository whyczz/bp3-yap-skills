---
name: teach
description: "Explain a concept, system, or diff from first principles, grounded in this repo, so the user builds intuition they can reuse."
---

# Teach

Use when the user explicitly invokes this skill, asks a noob question, or
wants to understand a change well enough to judge the next one. The
product is the user's intuition, not a summary.

## Procedure

1. Find the user's actual level from the question. Answer that question,
   not the graduate seminar behind it.
2. Ground everything in this repo or this diff. Open the real files and
   cite them; explain the concrete thing before the general pattern.
3. Teach in this order:
   - The concept in one plain paragraph, no jargon.
   - Before: how it worked, or what existed, before this change.
   - The change: what is different now, named by file and identifier.
   - After: how it behaves now, including one worked example traced
     through the code.
   - Layer walk, only as deep as the question needs: interface, then
     mechanism, then the detail that usually bites.
4. End with transfer: the one or two cues the user can use next time to
   recognize this pattern without you.

## Output

Short headed sections matching the procedure. Keep code quotes tiny and
load-bearing. Include an ASCII diagram only when relationships are the
confusing part.

## Rules

- Never explain from memory of "how these systems usually work" when the
  repo is right there. Read it.
- Say what you did not verify. A confident story about unread code is
  worse than a gap.
- No condescension and no trivia. If the user already knows a layer,
  skip it in one line and go deeper.
- Save a learning note only when the user asks for a file; suggest
  `docs/learn/` as its home.
