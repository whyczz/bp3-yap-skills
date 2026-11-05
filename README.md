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

The designed roster in bp3-docs also names `ask`, `red-chair`, `search`,
`teach`, `dossier`, `swipe`, `tldr`, `debug`, `verify`, and `add-skill`.
They enter this repo only through the `add-skill` gates; a roster entry is
not an implementation.

## Layout

```text
skills/<skill-id>/SKILL.md.j2   authored source, one directory per skill
templates/skill/SKILL.md.j2     scaffolder template
harnesses.toml                  harness paths and invocation spellings
src/yap/                        renderer, linter, scaffolder, installer
tests/                          tooling tests
generated/                      render output (not committed)
```

## Use

Requirements: Python 3.11+ and uv. Jinja2 is an authoring-time dependency
only; installed skills are plain Markdown with no Python dependency.

```sh
uv run yap check
uv run yap render --harness pi
uv run yap render --all
uv run yap install --harness pi --target /path/to/project
uv run yap new <skill-id> --description "<one sentence>"
uv run pytest
```

`install --harness pi` is the tested v1 path. It writes rendered skills to
`<target>/.pi/skills/<skill-id>/SKILL.md` and records hashes in
`<target>/.pi/skills/yap-skills.lock.json`. It refuses to overwrite a file
it did not install unless `--force` is given.

## Authoring rules

- One job per skill, stated in one sentence in the frontmatter description.
- Templates may use the harness context (`harness.id`, `harness.display`,
  `invocation`, `skill_id`, `version`) and narrow conditionals for real
  harness differences. No custom filters, macros, or logic that changes the
  skill's behavior per harness without a test naming the difference.
- Rendered files are derived. Never hand-edit `generated/`.
- A new skill starts with `yap new`, but scaffolding is not approval. The
  add-skill gates (prior-art search, red chair, adversarial trigger tests,
  and optional Archive evidence) decide whether it stays.

The implementation red chair and locked v1 decisions are in
[docs/implementation-redchair.md](docs/implementation-redchair.md).
