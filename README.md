# bp3-yap-skills

Human-invoked design skills for coding agents. A person invokes a skill by
name to design something or to get one specified output shape from the LLM.
The human is the operator and the check.

Yap skills are portable Markdown. They hold no state, install no hooks, and
ship no harness extensions. Anything that needs Board state, tool blocking,
or runtime code belongs in bp3 control or worker.

## Status

Version 0.1.0 contains the authoring toolchain and one implemented skill:

| Skill | Job | Status |
|---|---|---|
| `iiuc` | Messy input to TL;DR and IIUC playback, then stop | implemented |
| `ask` | Interview until a buildable request is clear | implemented |
| `search` | Search repo, history, web, archive; report with sources | implemented |
| `red-chair` | Read-only adversarial pass with next steps | implemented |
| `teach` | First-principles explanation grounded in the repo | implemented |
| `dossier` | Deep-dive learning document; explores, never decides | implemented |
| `design` | Proposed design: context, data models, functions, storage, milestones | implemented |
| `swipe` | External-repo adoption report with citations | implemented |
| `tldr` | Read-only primer over a diff for a human reviewer | implemented |
| `debug` | Root cause proven before any fix | implemented |
| `verify` | Fresh checks and exact outputs before "done" | implemented |
| `commit` | Commit message: TL;DR, For humans, For LLMs | implemented |
| `add-skill` | Gatekeeper for adding the next skill | implemented |

The full designed roster from bp3-docs is implemented above. The next
skill enters only through the `add-skill` gates; a roster entry in a
design doc is not an implementation.

## Layout

```text
skills/<skill-id>/SKILL.md.j2   authored source, one directory per skill
templates/skill/SKILL.md.j2     scaffolder template
harnesses.json                  harness paths and invocation spellings
retired-skills.json             retired ids, replacement (or null), and reason
lib/, bin/                      OCaml renderer, linter, scaffolder, installer
tests/                          tooling tests
generated/                      render output (not committed)
```

## Use

Requirements: OCaml 5.1+, opam, and dune. Build once with `opam install . --deps-only` (or use an existing switch with cmdliner and yojson), then `dune build`. Installed skills are plain Markdown with no runtime dependency.

```sh
make check                        # build + dune render check + tests
dune build @render                # canonical check: lint and render every harness
dune exec yap -- render --root . --harness pi
dune exec yap -- install --root . --harness pi -p --target /path/to/project
dune exec yap -- install --root . --harness pi -g
dune exec yap -- new <skill-id> --description "<one sentence>"
./scripts/install-hooks.sh        # enable the committed pre-commit gate
make install                      # dune install: put the yap binary in the switch
make install-skills               # install skills: [harness|all] [global|local-dir]
                                  #   make install-skills pi global
                                  #   make install-skills all        (all harnesses, global)
                                  #   make install-skills pi local-dir DIR=/path/to/project
```

Harness selection, for `render` and `install`, is a CLI input only:
`--harness` flags (comma-separated or repeated, for example
`--harness pi,codex,claude`), defaulting to pi alone. No environment
variable selects harnesses. `render --all` ignores `--harness`.
Selecting two
harnesses that share one skills root in the chosen scope (Codex and Muse
in `.agents/skills`) is refused before anything is written.

Plugin bundles: `dune exec yap -- plugin --root . --harness pi,claude,codex,muse`
writes `generated/plugin/<harness>/bp3/`. Claude and Codex namespace the
skills as `bp3:<skill>` (`/bp3:iiuc` on Claude, `$bp3:iiuc` on Codex).
Muse installs the same bundle as a native plugin (skill ids
`plugin:bp3:<skill>`). Pi has no plugin namespace, so it ships a pi
package: skills stay `/skill:<name>` and generated prompts give
`/<name>`. Only harnesses with a real plugin or package system get a
bundle; the bundle is a distribution wrapper, not a new source.

Rendered output is plain Markdown under `generated/<harness>/`: a portable
`SKILL.md` per skill, plus, for pi only, a prompt template at
`.pi/prompts/<skill>.md`. That template is what gives pi the exact
`/<skill>` command (for example `/iiuc`); the skill itself remains
available as `/skill:<skill>`.

Install scope is explicit and mutually exclusive: `-p`/`--project` or
`-g`/`--global`. Per project, pi writes `<project>/.pi/skills/<id>/SKILL.md`
and `<project>/.pi/prompts/<id>.md`. Global pi writes
`~/.pi/agent/skills/<id>/SKILL.md` and `~/.pi/agent/prompts/<id>.md`
(or under `$PI_CODING_AGENT_DIR`). Other harnesses take their conventional
global bases (`~/.claude`, `~/.agents`, `~/.config/muse`). Installs record scope, harness,
and content hashes in `yap-skills.lock.json` beside the skills,
and refuse to overwrite a file they did not install unless `--force` is
given. Global yap skills are the default way the CEO gets `/iiuc`
everywhere; per-project installs pin or override a version for one repo,
and the installer refuses to layer a second harness variant into a root
already managed for another harness.

## Duplicate discovery in Pi

Pi discovers both its own skills and Agent Skills directories (`~/.agents/skills`
and project `.agents/skills`). Installing Pi and Codex variants therefore used
to produce duplicate-name warnings. Pi installs now merge one exclusion per
active yap skill into the scope's `settings.json`, for example:

```json
{"skills": ["!**/.agents/skills/ask/SKILL.md"]}
```

This selects the Pi render without deleting Codex/Muse files or hiding unrelated
skills. Existing preferences and resource entries are preserved; repeated installs
do not duplicate the generated entries. Exclusions are additive, not automatically
removed. Pi packages alone do not perform this installer configuration.

Pi applies these exclusions **per scope**: user settings exclude user-discovered
copies, and project settings exclude project-discovered copies. A global install
does not change arbitrary projects. If an old project `.agents/skills/iiuc` shadows
your global Pi skill, add `!**/.agents/skills/iiuc/SKILL.md` to that project's
`.pi/settings.json` `skills` list. This preserves the old file while preferring the
Pi variant. Explicit `+path` entries can override glob exclusions. Intentional
project/global Pi overrides may still generate collision warnings.

## Retiring or renaming a skill

Deleting a source alone does **not** authorize deletion of installed files.
Record the retirement in `retired-skills.json`; keep the entry permanently so
users upgrading from older versions get cleanup too:

```json
{
  "commit-fmt": {
    "replacement": "commit",
    "reason": "Renamed to commit."
  }
}
```

Use `null` for `replacement` when there is no successor. Retired ids cannot
remain active, replacements must be active, and every retirement needs a reason.
`yap check` validates this registry.

On the next install for each harness/scope, the installer removes the retired
`SKILL.md` and corresponding Pi prompt only if the existing lock records ownership
for that harness and scope **and** the current content hash matches. Modified,
untracked, or symlinked files are preserved and reported, even with `--force`.
Only empty skill directories are removed; unrelated files survive. Successful
removals move out of the lock's `files` inventory into its append-only `removals`
history (key, path, content hash, toolchain version, and removal time). Missing
files simply leave the inventory. Corrupt locks fail closed.

Preview before applying:

```sh
dune exec yap -- install --root . --harness pi -g --dry-run
dune exec yap -- install --root . --harness pi -g
```

`--dry-run` previews writes on stdout and retirement decisions on stderr; it
changes neither installed files nor settings/locks. Install each harness to clean
its own files. There is no recursive deletion or general untracked-file pruning.

The regular gate is `make check`. To also exercise the installed Pi discovery
implementation with temporary user/project directories:

```sh
PI_PACKAGE_ROOT=/path/to/@earendil-works/pi-coding-agent node test/pi-discovery.mjs
```

## Authoring rules

- One job per skill, stated in one sentence in the frontmatter description.
- Templates use a deliberately tiny Jinja-shaped engine in `lib/template.ml`: variables (`skill_id`, `version`, `invocation`, `harness.id`, `harness.display`) and `if ==` / `if !=` conditionals only. No filters, macros, or loops. Logic that changes a skill's behavior per harness needs a test naming the difference.
- Rendered files are derived. Never hand-edit `generated/`.
- A new skill starts with `yap new`, but scaffolding is not approval. The
  add-skill gates (prior-art search, red chair, adversarial trigger tests,
  and optional Archive evidence) decide whether it stays.

The implementation red chair and locked v1 decisions are in
[docs/implementation-redchair.md](docs/implementation-redchair.md).
