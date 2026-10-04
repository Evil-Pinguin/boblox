#!/usr/bin/env python3
"""Run the pure-Lua MazeGen test suite under lupa (a real Lua interpreter).

MazeGen.lua is deliberately Roblox-free, so we can inline it, append the test
body, and execute it for real - no Studio required.
"""
import pathlib
import sys

import lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
rt = lupa.LuaRuntime(unpack_returned_tuples=True)

module = (ROOT / "src/shared/MazeGen.lua").read_text()
tests = (ROOT / "tools/test_maze.lua").read_text()

src = "local MazeGen = (function()\n" + module + "\nend)()\n" + tests

try:
    rt.execute(src)
except Exception as exc:  # noqa: BLE001 - surface the Lua traceback verbatim
    print(exc)
    sys.exit(1)

# Also compile-check every shipped Lua source file, including the ones that need
# the Roblox globals (they are never executed here, only parsed).
bad = 0
files = sorted((ROOT / "src").rglob("*.lua"))
for path in files:
    try:
        rt.compile(path.read_text())
    except Exception as exc:  # noqa: BLE001
        bad += 1
        print(f"SYNTAX {path.relative_to(ROOT)}: {exc}")
print(f"syntax: compiled {len(files)} files, {bad} failures")
sys.exit(1 if bad else 0)
