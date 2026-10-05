#!/usr/bin/env python3
"""Merges an agent's isolated working copy back into the live project.

An agent gets a copy of the project (work) made from a snapshot (base). When it is done, every file it changed
or created is brought into the live tree: copied when the live file is still the snapshot's, merged three-way
(git merge-file) when the live file has changed too. Nothing is written without --apply.

Usage: merge_work.py <base> <work> <live> [--apply]
"""
import filecmp
import os
import shutil
import subprocess
import sys

SUBDIRS = ("src", "docs", "tools")
SKIP_SUFFIXES = (".rbxl", ".rbxlx", ".pyc")


def files_under(root):
    found = set()
    for subdir in SUBDIRS:
        top = os.path.join(root, subdir)
        for folder, _, names in os.walk(top):
            for name in names:
                if name.endswith(SKIP_SUFFIXES) or name == ".DS_Store":
                    continue
                found.add(os.path.relpath(os.path.join(folder, name), root))
    return found


def same(a, b):
    return os.path.exists(a) and os.path.exists(b) and filecmp.cmp(a, b, shallow=False)


def main():
    args = [arg for arg in sys.argv[1:] if arg != "--apply"]
    apply = "--apply" in sys.argv[1:]
    if len(args) != 3:
        sys.exit(__doc__)
    base, work, live = args
    copied, merged, conflicts, created, unchanged = [], [], [], [], 0

    for path in sorted(files_under(work)):
        in_base, in_work, in_live = (os.path.join(root, path) for root in (base, work, live))
        if same(in_base, in_work):
            unchanged += 1
            continue
        if not os.path.exists(in_base):
            if not os.path.exists(in_live):
                created.append(path)
                if apply:
                    os.makedirs(os.path.dirname(in_live), exist_ok=True)
                    shutil.copy2(in_work, in_live)
            elif not same(in_work, in_live):
                conflicts.append(path + "  (new in the copy, but the live tree has a different file there)")
            continue
        if same(in_work, in_live):
            continue
        if not os.path.exists(in_live):
            conflicts.append(path + "  (changed in the copy, deleted in the live tree)")
            continue
        if same(in_base, in_live):
            copied.append(path)
            if apply:
                shutil.copy2(in_work, in_live)
            continue
        # Both changed it: merge the copy's changes into the live file.
        result = subprocess.run(["git", "merge-file", "-p", in_live, in_base, in_work], capture_output=True)
        if result.returncode == 0:
            merged.append(path)
            if apply:
                with open(in_live, "wb") as handle:
                    handle.write(result.stdout)
        else:
            conflicts.append(f"{path}  ({result.returncode} conflicting hunks)")
            marked = in_work + ".conflict"
            with open(marked, "wb") as handle:
                handle.write(result.stdout)

    removed = sorted(path for path in files_under(base) - files_under(work) if os.path.exists(os.path.join(live, path)))

    print(("APPLIED" if apply else "DRY RUN") + f": {unchanged} files untouched by the agent")
    for title, paths in (("new", created), ("copied", copied), ("merged", merged), ("CONFLICT", conflicts), ("deleted in the copy (left alone)", removed)):
        for path in paths:
            print(f"  {title}: {path}")
    sys.exit(1 if conflicts else 0)


if __name__ == "__main__":
    main()
