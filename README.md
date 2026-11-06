# bp3-yap-skills

Human-invoked design skills for coding agents. A person invokes a skill by
name to get one specified kind of thinking or output from the LLM.
The human is the operator and the check.

Skills are **static, portable Markdown**. They hold no state, install no
hooks, and ship no harness extensions. Anything that needs Board state,
tool blocking, or runtime code belongs in bp3 control or worker.

## Skills

| Skill | Job |
|---|---|
| `iiuc` | Messy input to TL;DR and IIUC playback, then stop |
| `ask` | Interview until a buildable request is clear |
| `search` | Search repo, history, web, archive; report with sources |
| `red-chair` | Read-only adversarial pass with next steps |
| `teach` | First-principles explanation grounded in the repo |
| `dossier` | Deep-dive learning document; explores, never decides |
| `design` | Proposed design: context, data models, functions, storage, milestones |
| `swipe` | External-repo adoption report with citations |
| `tldr` | Read-only primer over a diff for a human reviewer |
| `debug` | Root cause proven before any fix |
| `verify` | Fresh checks and exact outputs before "done" |
| `commit` | Commit message: TL;DR, For humans, For LLMs |
| `add-skill` | Gatekeeper for adding the next skill |

A new skill enters through the `add-skill` gates; scaffolding alone is not approval.

## Setup

Requirements: Bash 3.2+, **Mike Farah's Go-based yq v4**, and jq.
Development checks additionally use ShellCheck. No OCaml, opam, dune,
Ruby, Python, or template engine is required. Installed skills have no
runtime dependency on these authoring tools.

On macOS, install the dependencies from the committed `Brewfile`:

```sh
brew bundle
# Or: brew install yq jq shellcheck
make check
```

On other Unix systems, install those same tools using your package manager.
The Python-based tool also named `yq` is not compatible; the CLI checks
that Mike Farah yq v4 is present. Standard Unix utilities including `find`,
`awk`, `mktemp`, and `md5` (macOS) or `md5sum` (Linux) are also used.

## Layout

```text
skills/<id>/SKILL.md    canonical authored content, not generated
scripts/yap            Bash CLI: check, render, plugin, install, new, list
scripts/common.sh      validation and packaging helpers; yq parses YAML
scripts/install.sh     managed installer and retirement safeguards
templates/skill.md     static scaffold body
harnesses.json         harness install paths and invocation metadata
retired-skills.json    explicit retirements and replacement/reason metadata
Brewfile               runtime and development dependencies
test/                  shell integration tests and optional Pi discovery test
generated/             derived packaging output (not committed)
```

## Check and author

```sh
make check                       # ShellCheck + content checks + integration tests
make test                        # integration tests only
./scripts/yap check              # validate canonical sources
./scripts/yap check --json       # [] on success; errors go to stderr, exit nonzero
./scripts/yap list --json
./scripts/yap new <id> --description "One sentence stating the job."
./scripts/install-hooks.sh       # opt into the committed make-check pre-commit gate
```

The checker uses yq to parse actual YAML, including quoted and multiline
values. It requires a mapping with nonempty string `name` and `description`,
rejects duplicate YAML keys, and checks that `name` matches the directory.
It also checks valid skill IDs (including reserved-name rejection), exactly
one `SKILL.md` per skill, no TODO scaffold or template markers, a 500-line
ceiling, README roster consistency, and retirement registry validity.

There are **no substitutions or harness conditionals in skill content**.
Write `name: iiuc` directly. Trigger prose says when to invoke the skill,
not which harness-specific command spells its name. Scaffolding writes
TODOs that intentionally fail checks until the skill is authored.

## Package

```sh
make render                      # copy static skills into all harness layouts
./scripts/yap render --harness pi
make package                     # plugin/package bundles for every harness
./scripts/yap plugin --harness pi,claude,codex,muse
```

`render` and `plugin` copy each `SKILL.md` byte-for-byte. `render` defaults
to `generated/<harness>/`; `plugin` defaults to
`generated/plugin/<harness>/bp3/`. Both accept `--out DIR` and validate
sources before writing. Output directories are not automatically pruned;
use a fresh output directory when producing a release after a retirement.
Never edit generated output.

Only packaging metadata is generated:

- Pi prompt wrappers provide exact `/<id>` commands and forward
  `${ARGUMENTS:-}`. Skills themselves remain available as `/skill:<id>`.
- Pi packages have a `package.json` declaring skills and prompts.
- Claude, Codex, and Muse bundles have native plugin manifests.
  Claude and Codex namespace invocation as `/bp3:<id>` and `$bp3:<id>`;
  Muse uses native plugin skill IDs. The skill body stays unchanged.

Harness selection is a CLI input: `--harness` accepts comma-separated or
repeated values, defaulting to Pi. No environment variable selects
harnesses. `render --all` selects every harness. `--root DIR` selects a
source repository; by default the scripts use their own checkout.
`--json` returns file-path arrays for packaging and installation.

## Install

```sh
./scripts/yap install --harness pi -g
./scripts/yap install --harness pi -p --target /path/to/project
./scripts/yap install --harness pi -g --dry-run
make install-skills pi global
make install-skills pi local-dir DIR=/path/to/project
make install-skills all           # all harnesses, using their global bases
```

Scope is explicit and mutually exclusive: `-p`/`--project` requires
`--target DIR`; `-g`/`--global` defaults to the harness's global base.
For a single global harness, `--target DIR` overrides that base.

| Harness | Project skills | Global base |
|---|---|---|
| Pi | `.pi/skills` | `$PI_CODING_AGENT_DIR` or `~/.pi/agent` |
| Claude | `.claude/skills` | `~/.claude` |
| Codex | `.agents/skills` | `~/.agents` |
| Muse | `.agents/skills` | `$XDG_CONFIG_HOME/muse` or `~/.config/muse` |

Global skills live under `skills/` in each base. Pi also installs prompt
wrappers under `.pi/prompts` (project) or `prompts/` (global).

Installs maintain `yap-skills.lock.json` beside the skills. Existing files
are overwritten only if their content fingerprint matches the recorded
ownership, unless `--force` is explicit. Symlinked write paths are refused,
even with force. Lock fingerprints retain the original tool's **MD5**
format for compatibility; they detect local edits, not malicious tampering.
Existing OCaml-era locks can be used without reinstalling with force.
Corrupt locks/settings fail closed. All selected harnesses are preflighted
before any installation writes or retirement deletions, although installs
are not transactional against I/O failures or concurrent writers.

Two harnesses sharing a skills root in the selected scope (Codex and Muse
in a project) are refused before writing. An already managed root cannot
switch harness or scope without `--force`.

### Pi discovery settings

Pi also discovers `.agents/skills`. To prefer Pi's copy without deleting
Codex/Muse files, the installer merges one exclusion per active skill into
the scope's `settings.json`, for example:

```json
{"skills": ["!**/.agents/skills/ask/SKILL.md"]}
```

Other settings and existing resource entries survive; repeated installs
are idempotent. Exclusions are additive, not automatically removed. Pi
packages alone do not perform this installer configuration.

Exclusions apply **per scope**. A global install does not modify arbitrary
projects. An old project `.agents/skills/iiuc` needs the exclusion in that
project's `.pi/settings.json`. Explicit `+path` entries can override glob
exclusions; intentional project/global Pi overrides may still warn.

### Retirements

Deleting a source does **not** authorize deleting installed files. Record
retired IDs permanently in `retired-skills.json`:

```json
{"commit-fmt": {"replacement": "commit", "reason": "Renamed to commit."}}
```

`replacement` may be null. Retired IDs cannot remain active; replacements
must exist, and reasons must be nonempty. On install, only files owned by
the same harness/scope and still matching the lock are removed. Modified,
foreign, or symlinked retired files survive **even with `--force`**.
Only empty skill directories are removed; unrelated assets survive.
Removals enter the lock's append-only history. Missing files simply leave
the inventory. `--dry-run` previews paths on stdout and retirement decisions
on stderr without changing files, settings, or locks.

## Verification and migration

`make check` is the regular gate. The optional test against an installed
Pi uses isolated user/project directories:

```sh
PI_PACKAGE_ROOT=/path/to/@earendil-works/pi-coding-agent node test/pi-discovery.mjs
```

This refactor replaces `dune exec yap -- ...` with `./scripts/yap ...`.
`make install` now aliases skill installation; there is no compiled CLI to
install. The former `*.j2` files are now canonical `SKILL.md` files.
Harness discovery history is in [docs/harness-tests.md](docs/harness-tests.md).
The earlier implementation decision record is historical and superseded
by this static-Markdown/Bash toolchain.
