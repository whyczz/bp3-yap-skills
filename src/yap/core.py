"""Core model: harness matrix, skill discovery, rendering, lint, scaffold."""

from __future__ import annotations

import hashlib
import json
import re
import tomllib
from dataclasses import dataclass
from pathlib import Path

from jinja2 import Environment, FileSystemLoader, StrictUndefined

ROOT = Path(__file__).resolve().parents[2]
SKILL_ID_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
RESERVED = {
    "con", "prn", "aux", "nul",
    *(f"com{i}" for i in range(1, 10)),
    *(f"lpt{i}" for i in range(1, 10)),
}
MAX_SKILL_LINES = 500
CONDITIONAL_WARN = 4


@dataclass(frozen=True)
class Harness:
    id: str
    display: str
    skills_dir: str
    invocation_format: str
    tested: bool

    def invocation(self, skill_id: str) -> str:
        return self.invocation_format.format(skill=skill_id)


@dataclass(frozen=True)
class Diagnostic:
    level: str  # "error" or "warning"
    message: str

    def __str__(self) -> str:
        return f"{self.level}: {self.message}"


def load_harnesses(root: Path = ROOT) -> dict[str, Harness]:
    data = tomllib.loads((root / "harnesses.toml").read_text(encoding="utf-8"))
    return {
        key: Harness(
            id=key,
            display=str(row["display"]),
            skills_dir=str(row["skills_dir"]),
            invocation_format=str(row["invocation"]),
            tested=bool(row.get("tested", False)),
        )
        for key, row in sorted(data["harness"].items())
    }


def valid_skill_id(skill_id: str) -> bool:
    return bool(SKILL_ID_RE.fullmatch(skill_id)) and skill_id not in RESERVED


def skill_sources(root: Path = ROOT) -> list[Path]:
    skills_dir = root / "skills"
    if not skills_dir.is_dir():
        return []
    return sorted(skills_dir.glob("*/SKILL.md.j2"))


def version(root: Path = ROOT) -> str:
    return (root / "VERSION").read_text(encoding="utf-8").strip()


def _environment(root: Path) -> Environment:
    return Environment(
        loader=FileSystemLoader(str(root / "skills")),
        undefined=StrictUndefined,
        autoescape=False,
        keep_trailing_newline=True,
    )


def render_skill(root: Path, source: Path, harness: Harness) -> str:
    skill_id = source.parent.name
    template = _environment(root).get_template(f"{skill_id}/SKILL.md.j2")
    body = template.render(
        skill_id=skill_id,
        version=version(root),
        invocation=harness.invocation(skill_id),
        harness={"id": harness.id, "display": harness.display},
    )
    return body


def render_all(
    root: Path = ROOT, harness_ids: list[str] | None = None
) -> dict[str, dict[str, str]]:
    harnesses = load_harnesses(root)
    ids = harness_ids or list(harnesses)
    out: dict[str, dict[str, str]] = {}
    for harness_id in ids:
        harness = harnesses[harness_id]
        out[harness_id] = {
            source.parent.name: render_skill(root, source, harness)
            for source in skill_sources(root)
        }
    return out


def write_rendered(root: Path, out_dir: Path, harness_ids: list[str] | None = None) -> list[Path]:
    rendered = render_all(root, harness_ids)
    harnesses = load_harnesses(root)
    written: list[Path] = []
    for harness_id, skills in rendered.items():
        harness = harnesses[harness_id]
        for skill_id, body in skills.items():
            dest = out_dir / harness.skills_dir / skill_id / "SKILL.md"
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(body, encoding="utf-8")
            written.append(dest)
    return written


def _frontmatter(body: str) -> dict[str, str] | None:
    if not body.startswith("---\n"):
        return None
    end = body.find("\n---", 4)
    if end == -1:
        return None
    fields: dict[str, str] = {}
    for line in body[4:end].splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            fields[key.strip()] = value.strip()
    return fields


def lint(root: Path = ROOT) -> list[Diagnostic]:
    diagnostics: list[Diagnostic] = []
    sources = skill_sources(root)
    if not sources:
        diagnostics.append(Diagnostic("error", "no skills found under skills/"))
        return diagnostics

    readme = (root / "README.md").read_text(encoding="utf-8")
    harnesses = load_harnesses(root)

    for source in sources:
        skill_id = source.parent.name
        if not valid_skill_id(skill_id):
            diagnostics.append(Diagnostic("error", f"invalid skill id: {skill_id}"))
        siblings = sorted(p.name for p in source.parent.iterdir())
        if siblings != ["SKILL.md.j2"]:
            diagnostics.append(
                Diagnostic("error", f"{skill_id}: expected only SKILL.md.j2, found {siblings}")
            )
        text = source.read_text(encoding="utf-8")
        if "TODO:" in text:
            diagnostics.append(Diagnostic("error", f"{skill_id}: TODO scaffold text remains"))
        if len(text.splitlines()) > MAX_SKILL_LINES:
            diagnostics.append(
                Diagnostic("error", f"{skill_id}: over {MAX_SKILL_LINES} lines")
            )
        conditionals = text.count("{% if") + text.count("{% elif")
        if conditionals > CONDITIONAL_WARN:
            diagnostics.append(
                Diagnostic(
                    "warning",
                    f"{skill_id}: {conditionals} harness conditionals; each needs a named test",
                )
            )
        if f"`{skill_id}`" not in readme:
            diagnostics.append(Diagnostic("error", f"{skill_id}: missing from README roster"))

        for harness in harnesses.values():
            try:
                body = render_skill(root, source, harness)
            except Exception as exc:  # Jinja errors are lint findings, not crashes.
                diagnostics.append(
                    Diagnostic("error", f"{skill_id} [{harness.id}]: render failed: {exc}")
                )
                continue
            if "{{" in body or "{%" in body:
                diagnostics.append(
                    Diagnostic("error", f"{skill_id} [{harness.id}]: unresolved template markers")
                )
            fields = _frontmatter(body)
            if fields is None:
                diagnostics.append(
                    Diagnostic("error", f"{skill_id} [{harness.id}]: missing frontmatter")
                )
                continue
            if fields.get("name") != skill_id:
                diagnostics.append(
                    Diagnostic(
                        "error",
                        f"{skill_id} [{harness.id}]: frontmatter name is {fields.get('name')!r}",
                    )
                )
            if not fields.get("description"):
                diagnostics.append(
                    Diagnostic("error", f"{skill_id} [{harness.id}]: empty description")
                )
    return diagnostics


def scaffold(root: Path, skill_id: str, description: str) -> Path:
    if not valid_skill_id(skill_id):
        raise ValueError(f"invalid skill id: {skill_id!r}")
    dest_dir = root / "skills" / skill_id
    if dest_dir.exists():
        raise FileExistsError(f"skill already exists: {skill_id}")
    template = (root / "templates" / "skill" / "SKILL.md.j2").read_text(encoding="utf-8")
    body = template.replace("{{ skill_id }}", skill_id)
    if description:
        body = body.replace(
            "TODO: one sentence stating the job this skill does.", description
        )
    dest_dir.mkdir(parents=True)
    dest = dest_dir / "SKILL.md.j2"
    dest.write_text(body, encoding="utf-8")
    return dest


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def install(
    root: Path, target: Path, harness_id: str, force: bool = False
) -> list[Path]:
    harnesses = load_harnesses(root)
    if harness_id not in harnesses:
        raise ValueError(f"unknown harness: {harness_id}")
    harness = harnesses[harness_id]
    rendered = render_all(root, [harness_id])[harness_id]

    skills_root = target / harness.skills_dir
    lock_path = skills_root / "yap-skills.lock.json"
    lock: dict = {"version": version(root), "harness": harness_id, "files": {}}
    if lock_path.is_file():
        try:
            lock = json.loads(lock_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            lock = {"version": version(root), "harness": harness_id, "files": {}}
    recorded: dict[str, str] = lock.get("files", {})

    written: list[Path] = []
    for skill_id, body in rendered.items():
        dest = skills_root / skill_id / "SKILL.md"
        if dest.is_file() and not force:
            current = sha256_text(dest.read_text(encoding="utf-8"))
            if recorded.get(skill_id) != current:
                raise FileExistsError(
                    f"refusing to overwrite hand-edited or foreign file: {dest} "
                    "(pass --force to replace it)"
                )
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(body, encoding="utf-8")
        recorded[skill_id] = sha256_text(body)
        written.append(dest)

    lock.update({"version": version(root), "harness": harness_id, "files": recorded})
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock_path.write_text(json.dumps(lock, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return written
