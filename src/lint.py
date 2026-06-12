#!/usr/bin/env python3
"""Lint Containerfile install commands against staging conventions."""

import re
import sys
import pathlib

def lint_containerfile(path):
    issues = []
    text = path.read_text()
    for lineno, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if not stripped.startswith("install ") and not stripped.startswith("mkdir -p "):
            continue

        # install must have -v
        if stripped.startswith("install "):
            if "-vD" not in stripped and "-vd" not in stripped and not stripped.startswith("install -v"):
                issues.append((lineno, line, "install missing -v flag"))

        # mkdir -p should be install -vdm
        if stripped.startswith("mkdir -p "):
            issues.append((lineno, line, "use install -vdm0755 instead of mkdir -p"))

        # install -D must use -t with target dir first
        m = re.search(r"install\s+[-vDd]+\S+\s+(-t\s+)?(/rootfs/\S+?)(/?)(\s+)(\S+)", stripped)
        if m and "-t " not in stripped and "DESTDIR" not in stripped:
            target = m.group(2)
            trail = m.group(3)
            if trail == "/":
                issues.append((lineno, line, "trailing slash on target dir"))

    return issues

def main():
    root = pathlib.Path(__file__).resolve().parent.parent
    pkgs = list(root.glob("packages/core/*/Containerfile")) + list(root.glob("packages/user/*/Containerfile"))
    total = 0
    for p in sorted(pkgs):
        for lineno, line, msg in lint_containerfile(p):
            rel = p.relative_to(root)
            print(f"{rel}:{lineno}: {msg}")
            print(f"  {line.strip()}")
            total += 1
    if total:
        print(f"\n{total} issue(s) found")
        return 1
    print("OK")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
