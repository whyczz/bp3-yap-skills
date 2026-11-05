"""Command line surface: check, render, install, new, list."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .core import (
    ROOT,
    install,
    lint,
    load_harnesses,
    render_all,
    scaffold,
    skill_sources,
    write_rendered,
)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="yap", description="bp3 yap skills toolchain")
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("check", help="lint sources and render every harness")

    render = sub.add_parser("render", help="render skills")
    render.add_argument("--harness", help="one harness id")
    render.add_argument("--all", action="store_true", help="render every harness")
    render.add_argument("--out", type=Path, default=None, help="output root")

    install_cmd = sub.add_parser("install", help="install rendered skills into a project")
    install_cmd.add_argument("--harness", default="pi")
    install_cmd.add_argument("--target", type=Path, required=True)
    install_cmd.add_argument("--force", action="store_true")

    new = sub.add_parser("new", help="scaffold a new skill source")
    new.add_argument("skill_id")
    new.add_argument("--description", default="")

    sub.add_parser("list", help="list implemented skills and harnesses")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    root: Path = args.root

    try:
        if args.command == "check":
            diagnostics = lint(root)
            errors = [d for d in diagnostics if d.level == "error"]
            if args.json:
                print(json.dumps([{"level": d.level, "message": d.message} for d in diagnostics]))
            else:
                for diagnostic in diagnostics:
                    print(diagnostic)
                print("yap check: ok" if not errors else f"yap check: {len(errors)} error(s)")
            return 1 if errors else 0

        if args.command == "render":
            harness_ids = None
            if args.harness:
                harness_ids = [args.harness]
            elif not args.all:
                harness_ids = ["pi"]
            out = args.out or (root / "generated")
            written = write_rendered(root, out, harness_ids)
            if args.json:
                print(json.dumps([str(path) for path in written]))
            else:
                for path in written:
                    print(path)
            return 0

        if args.command == "install":
            written = install(root, args.target, args.harness, force=args.force)
            if args.json:
                print(json.dumps([str(path) for path in written]))
            else:
                for path in written:
                    print(path)
            return 0

        if args.command == "new":
            dest = scaffold(root, args.skill_id, args.description)
            print(dest)
            return 0

        if args.command == "list":
            skills = [source.parent.name for source in skill_sources(root)]
            harnesses = {
                harness_id: {
                    "display": harness.display,
                    "skills_dir": harness.skills_dir,
                    "invocation": harness.invocation("<skill>"),
                    "tested": harness.tested,
                }
                for harness_id, harness in load_harnesses(root).items()
            }
            if args.json:
                print(json.dumps({"skills": skills, "harnesses": harnesses}, indent=2))
            else:
                print("skills: " + ", ".join(skills))
                for harness_id, row in harnesses.items():
                    state = "tested" if row["tested"] else "render-only"
                    print(f"{harness_id}: {row['skills_dir']} ({state})")
            return 0
    except (ValueError, FileExistsError, FileNotFoundError, KeyError) as exc:
        print(f"yap: {exc}", file=sys.stderr)
        return 2

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
