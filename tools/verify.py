#!/usr/bin/env python3
"""verify.py - the whole offline test battery for BLACKSITE in one command.

Studio cannot run here, so this checks everything that can be checked without it:

	1. lint      every .lua file compiles under a strict Lua parser, and the output
	             flags Luau-only syntax that a plain parser would reject
	2. maze      the generator's invariants (connectivity, no sealed regions, LOS,
	             flow fields, reachability of every pickup tile)
	3. round sim boots the real server scripts in a Roblox engine mock and plays two
	             full rounds with fake crew: prompts, cells, the Hollow's AI, grabs,
	             deaths, respawns, lockers, escape, results, teardown, re-generation
	4. client sim boots the real client scripts against that server and checks HUD/menu/
	             input/effects, plus that nothing client-only leaks into replicated services
	5. place     regenerates Blacksite.rbxlx and re-validates the XML

Requirements: python3 with `lupa` (pip install lupa). No Roblox tooling needed.

Usage:
	python3 tools/verify.py            # run everything
	python3 tools/verify.py --quick    # skip the two simulations
"""
from __future__ import annotations

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def run(label: str, argv: list[str], quick_skip: bool = False) -> bool:
    if quick_skip and "--quick" in sys.argv:
        print(f"\n== {label}: skipped (--quick)")
        return True
    print(f"\n== {label}")
    proc = subprocess.run(argv, cwd=ROOT)
    ok = proc.returncode == 0
    print(f"== {label}: {'PASS' if ok else 'FAIL'}")
    return ok


def main() -> int:
    py = sys.executable
    results = [
        run("lint", [py, "tools/lint.py"]),
        run("maze generator", [py, "tools/test_maze.py"]),
        run("round simulation (server)", [py, "tools/sim.py"]),
        run("client simulation", [py, "tools/sim.py", "--client"]),
        run("place build", [py, "tools/build_place.py"]),
    ]
    print()
    if all(results):
        print("all checks passed")
        return 0
    print("FAILURES - see the output above")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
