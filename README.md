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
| `iiuc` | Turn messy or dictated input into a TL;DR and IIUC playback, then stop for confirmation | implemented |
| `commit-fmt` | Draft a commit message: TL;DR, For humans (ELI5, Problem, Solution), For LLMs (changed, contracts, verification, risk) | implemented |

The designed roster in bp3-docs also names `ask`, `red-chair`, `search`,
`teach`, `dossier`, `swipe`, `tldr`, `debug`, `verify`, and `add-skill`.
They enter this repo only through the `add-skill` gates; a roster entry is
not an implementation.

## Layout

```text
skills/<skill-id>/SKILL.md.j2   authored source, one directory per skill
templates/skill/SKILL.md.j2     scaffolder template
harnesses.json                  harness paths and invocation spellings
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
```

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
global bases (`~/.claude`, `~/.agents`). Installs record scope, harness,
and SHA-style content hashes in `yap-skills.lock.json` beside the skills,
and refuse to overwrite a file they did not install unless `--force` is
given. Global yap skills are the default way the CEO gets `/iiuc`
everywhere; per-project installs pin or override a version for one repo,
and the installer refuses to layer a second harness variant into a root
already managed for another harness.

## Authoring rules

- One job per skill, stated in one sentence in the frontmatter description.
- Templates use a deliberately tiny Jinja-shaped engine in `lib/template.ml`: variables (`skill_id`, `version`, `invocation`, `harness.id`, `harness.display`) and `if ==` / `if !=` conditionals only. No filters, macros, or loops. Logic that changes a skill's behavior per harness needs a test naming the difference.
- Rendered files are derived. Never hand-edit `generated/`.
- A new skill starts with `yap new`, but scaffolding is not approval. The
  add-skill gates (prior-art search, red chair, adversarial trigger tests,
  and optional Archive evidence) decide whether it stays.

The implementation red chair and locked v1 decisions are in
[docs/implementation-redchair.md](docs/implementation-redchair.md).
