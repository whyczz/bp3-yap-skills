import json
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from yap.core import install, lint, load_harnesses, render_all, scaffold


ROOT = Path(__file__).resolve().parents[1]


def test_harness_matrix_pi_tested_others_render_only():
    harnesses = load_harnesses(ROOT)
    assert harnesses["pi"].tested is True
    assert harnesses["pi"].invocation("iiuc") == "/skill:iiuc"
    assert harnesses["codex"].invocation("iiuc") == "$iiuc"


def test_render_iiuc_per_harness_no_leftovers():
    rendered = render_all(ROOT)
    assert rendered["pi"]["iiuc"].startswith("---\nname: iiuc")
    assert "`/skill:iiuc`" in rendered["pi"]["iiuc"]
    assert "`/iiuc`" in rendered["claude"]["iiuc"]
    assert "`$iiuc`" in rendered["codex"]["iiuc"]
    for skills in rendered.values():
        for body in skills.values():
            assert "{{" not in body
            assert "{%" not in body


def test_lint_clean_repo_has_no_errors():
    diagnostics = lint(ROOT)
    assert [d.message for d in diagnostics if d.level == "error"] == []


def test_scaffold_then_lint_rejects_todo(tmp_path):
    # Build a minimal repo copy around the scaffolded skill.
    (tmp_path / "skills").mkdir()
    (tmp_path / "templates" / "skill").mkdir(parents=True)
    (tmp_path / "templates" / "skill" / "SKILL.md.j2").write_text(
        (ROOT / "templates" / "skill" / "SKILL.md.j2").read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    (tmp_path / "harnesses.toml").write_text(
        (ROOT / "harnesses.toml").read_text(encoding="utf-8"), encoding="utf-8"
    )
    (tmp_path / "VERSION").write_text("0.1.0\n", encoding="utf-8")
    (tmp_path / "README.md").write_text("# x\n\n`demo-skill`\n", encoding="utf-8")

    dest = scaffold(tmp_path, "demo-skill", "Demo job in one sentence.")
    assert dest.is_file()
    errors = [d.message for d in lint(tmp_path) if d.level == "error"]
    assert any("TODO" in message for message in errors)

    with pytest.raises(FileExistsError):
        scaffold(tmp_path, "demo-skill", "again")


def test_install_pi_and_refuse_hand_edit(tmp_path):
    target = tmp_path / "project"
    written = install(ROOT, target, "pi")
    dest = target / ".pi" / "skills" / "iiuc" / "SKILL.md"
    assert written == [dest]
    assert dest.is_file()
    lock = json.loads((target / ".pi" / "skills" / "yap-skills.lock.json").read_text())
    assert lock["harness"] == "pi"
    assert "iiuc" in lock["files"]

    # Reinstall is a no-op success; a hand edit is refused without --force.
    install(ROOT, target, "pi")
    dest.write_text(dest.read_text(encoding="utf-8") + "\nhand edit\n", encoding="utf-8")
    with pytest.raises(FileExistsError):
        install(ROOT, target, "pi")
    install(ROOT, target, "pi", force=True)
    assert "hand edit" not in dest.read_text(encoding="utf-8")


def test_cli_check_and_render(tmp_path):
    env_root = str(ROOT)
    check = subprocess.run(
        [sys.executable, "-m", "yap", "--root", env_root, "check"],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
        env={"PATH": "/usr/bin:/bin:/usr/local/bin", "PYTHONPATH": str(ROOT / "src")},
    )
    assert check.returncode == 0, check.stdout + check.stderr

    out = tmp_path / "generated"
    render = subprocess.run(
        [
            sys.executable, "-m", "yap", "--root", env_root,
            "render", "--harness", "pi", "--out", str(out),
        ],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
        env={"PATH": "/usr/bin:/bin:/usr/local/bin", "PYTHONPATH": str(ROOT / "src")},
    )
    assert render.returncode == 0, render.stdout + render.stderr
    assert (out / ".pi" / "skills" / "iiuc" / "SKILL.md").is_file()
