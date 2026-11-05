# Harness tests

Battle-test record for rendered and installed yap skills. A harness is
marked `tested` in harnesses.json only when a real harness binary has
discovered the installed skill, not when a file merely exists.

## 2026-11-05, iiuc, isolated homes

Versions: pi 1.4.0, Claude Code 2.1.309, codex-cli 0.166.0,
Muse Code 1.4.14. Installs used `yap install -p` into scratch
projects and `yap install -g` into scratch global bases. No real user
home was touched.

| Harness | Project scope | Global scope | Method | Verdict |
|---|---|---|---|---|
| pi | prompt `iiuc` discovered, project scope | prompt `iiuc` and skill `iiuc` discovered, user scope | `pi --mode rpc` `get_commands` with scratch `PI_CODING_AGENT_DIR` | tested |
| Codex | skill listed in model-visible prompt input | skill listed in the same prompt input | `codex debug prompt-input` with scratch HOME/CODEX_HOME | tested |
| Muse | `iiuc` listed, project source | `iiuc` listed, user source | `muse skills list --json`, plus `muse skills validate` | tested |
| Claude | files installed at `.claude/skills/iiuc/SKILL.md` | files installed at `<base>/skills/iiuc/SKILL.md` | Path and common-subset validation only; `claude --bare --print` in a scratch HOME stops at "Not logged in" before skill discovery can be observed | render-only |

## Findings that change the design

1. Layering both scopes duplicates skills. Codex's prompt input listed
   `iiuc` twice when a scratch global install and project install were
   both visible. Pi keeps the first collision and warns; Claude and Muse
   have their own precedence or blocking rules. Rule: global is the
   default for yap skills; per-project is a pin or override. Do not layer
   both scopes for the same harness and project unless the point is to
   test precedence.
2. Pi's exact `/<skill>` command comes from a prompt template
   (`.pi/prompts/<skill>.md`), not from the skill. The renderer therefore
   emits both for pi: the portable `SKILL.md` (`/skill:<name>`) and the
   generated prompt template (`/<name>`).
3. Claude remains honestly unverified. Its install paths come from the
   bp2 harness matrix and the output passes the Agent Skills common
   subset, but no authenticated Claude run has observed discovery yet.
