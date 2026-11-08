# anon-writer adoption record

## Intent and clarification

Job: a human explicitly invokes `anon-writer` to produce a requested reply or
rewrite in Yap's house voice. The full guide also sets the default
communication voice through native instruction files, not auto-invocation.
The user subsequently requested the full setup in `AGENTS.md`, replacing the
initial summary-only approach. Installs now embed the Markdown body of
`skills/anon-writer/SKILL.md` without frontmatter; reinstalling migrates old
summary blocks in place.

The user identified BP2's skill, confirmed its voice, and requested both the
explicit skill and default communication voice. The repeated papercut in this
session was excessive verification output; the user also corrected a generic
voice proposal that lost the actual anon-writer tone.

Examples: `/skill:anon-writer Explain why a hand-edited lockfile broke the
build`; `Use anon-writer to rewrite this status update`; `Answer in Yap's anon
house voice: what is a sum type?`

Near misses: debug a build; clean dictated text with IIUC; return exact JSON.
Neither the default voice nor explicit invocation grants tool/execution rights.
Required output formats and explicit tone requests take precedence.

## Prior art, searched in gate order

| Source | Evidence and overlap | Absorb or not |
|---|---|---|
| Yap roster | `skills/iiuc/SKILL.md` explicitly requires plain playback; `skills/commit/SKILL.md` specifies a commit format. Neither owns general reply voice. | Don't absorb into unrelated workflows. |
| BP2 catalog | `/Users/whycz/m/bp2/catalog/skills/anon-writer/SKILL.md` is the exact requested guide; BP2 `AGENTS.md` has its short Style summary. | Port this existing skill, not a newly invented persona. Remove BP2-only metadata. |
| BP1 | No BP1 checkout found under `/Users/whycz/m` or the searched home directory depth. | Unchecked; not evidence of absence elsewhere. |
| Superpowers | https://github.com/obra/superpowers/blob/main/README.md describes a composable development methodology. | No reason to replace the exact requested house voice with a workflow. |
| Compound Engineering | https://github.com/EveryInc/compound-engineering-plugin/blob/main/README.md describes the brainstorm/plan/build/review/learn loop. A guessed `every-style-editor` raw path returned 404. | Overview inspected; style-editor guide not verified. |
| gstack | https://github.com/garrytan/gstack/blob/main/README.md describes engineering roles and slash-command workflows. | Not the requested house voice. |
| Anthropic skills | https://github.com/anthropics/skills/blob/main/skills/brand-guidelines/SKILL.md owns visual brand colors, typography, and artifacts. | Different style dimension; don't absorb an anon reply voice there. |
| Web search | Search for `agent skill anon writer house style` returned a Google redirect/challenge page. | Unchecked results; no claimed exhaustive internet search. |

These are bounded prior-art checks, not claims that no other writing skill
exists. The user selected the exact BP2 source.

## Archive mining

Unchecked: no archive miner was invoked. The current conversation supplies
direct user corrections, not an invented count of historical sessions.

## Pre-write red chair: engineering and trust boundaries

Verdict: proceed with the existing BP2 skill, fixing the following first.

1. **Wrong global home loses the default voice.** Codex skills live in
   `~/.agents/skills`, but native global instructions live in
   `$CODEX_HOME/AGENTS.md` (default `~/.codex/AGENTS.md`). Evidence:
   https://developers.openai.com/codex/guides/agents-md. Handle the two homes
   separately; an explicit global target remains an explicit staging base.
2. **Whole-file ownership would clobber personal instructions.** Existing
   `scripts/install.sh:validate_destination` treats skill files as entirely
   owned. Do not apply that model to agent instructions. Own only a marked
   block, preserve outside bytes, refuse symlinks and malformed/duplicate
   markers even with force, and preflight every harness before writing.
3. **Default persona can damage contracts and consume context.** Evidence:
   IIUC's explicit plain-tone requirement and the user's verification-output
   complaint. The initial design installed only a short summary. The user's
   subsequent request supersedes that choice: embed the full guide, while
   preserving its exact-format/explicit-tone boundaries. Humor is not a quota.
4. **Name collisions.** BP2 installs `bp2-anon-writer` for shared agent
   discovery, and its Claude skill is `anon-writer`. The Yap roster had no
   `anon-writer`. Existing installer foreign-file checks still apply; no
   bypass just because this skill was requested.
5. **Native precedence can shadow defaults.** Pi and Codex can prefer
   `AGENTS.override.md`. Warn rather than altering user overrides. Muse's
   installed binary identifies config-directory `AGENTS.md` and project
   `AGENTS.md`/`CLAUDE.md` rule files; live Muse loading is still unchecked.

Stateless test: the skill has no Board, queue, daemon, hook, or runtime state.
The installer uses native static Markdown instruction files. This does not
add a harness extension or an agent execution hook.

## Pre-write adversarial routing transcript

A draft was tested in an ephemeral Pi session with tools, extensions, MCP,
skill discovery, prompt discovery, and context-file loading disabled:

```sh
pi -p --no-session --no-tools --no-extensions --no-mcp --no-skills \
  --no-prompt-templates --no-context-files --offline --thinking minimal <prompt>
```

The prompt supplied the draft and asked for ROUTE/NO_ROUTE classification,
not task execution. The draft's trigger, body, and boundaries are retained
in the final skill; installer integration was added afterward. The raw local
transcript is `/tmp/yap-anon-writer-trigger-transcript.txt` (ephemeral).

```text
P1: /skill:anon-writer Explain why a hand-edited lockfile broke the build.
P1: ROUTE — Explicit `/skill:anon-writer` invocation.
P2: Use anon-writer to rewrite this status update.
P2: ROUTE — Explicitly requests anon-writer for a rewrite.
P3: Answer in Yap's anon house voice: what is a sum type?
P3: ROUTE — Explicitly requests Yap’s anon house voice.
N1: Debug the build and prove the root cause.
N1: NO_ROUTE — Debugging request, with no explicit voice invocation.
N2: Clean up this dictated transcript with iiuc.
N2: NO_ROUTE — Requests iiuc cleanup, not anon-writer.
N3: Return only JSON: {"ok": true}.
N3: NO_ROUTE — Requests exact JSON, not anon-writer.
H1: Find the anonymous writer of this blog post.
H1: NO_ROUTE — “Anonymous writer” refers to authorship, not the skill.
H2: Build an anon-writer daemon that watches the Board and auto-publishes replies.
H2: NO_ROUTE — Names a daemon to build, not a voice to apply.
exit: 0
```

This is a routing smoke test, not proof of deterministic model behavior or
live discovery in every harness. Before the full-guide change, `make check`
passed 304 assertions, including
native path shapes, preservation, idempotence, updates, dry runs, opt-out,
and fail-closed preflight. The optional `test/pi-discovery.mjs` check against
installed Pi 1.5.0 reports 14 Pi skills, the unrelated skill retained, zero
diagnostics, explicit-only anon-writer discovery, and both global/project
voice blocks loaded by Pi's native context loader. Live Claude/Codex/Muse
loading and model adherence to the default voice remain unchecked.
