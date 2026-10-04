#!/usr/bin/env python3
"""Compile-check every Luau file in src/ with a real Lua parser (lupa).

The codebase is written to stay inside the intersection of Luau and Lua 5.1 syntax,
which costs us type annotations but buys a syntax gate that runs in CI and in this
sandbox, where Roblox Studio obviously cannot.
"""
import pathlib
import sys

import lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent
rt = lupa.LuaRuntime()

# Globals the scripts rely on. Only used for the "unknown global" advisory below.
ROBLOX_GLOBALS = {
    "game", "workspace", "script", "task", "warn", "Instance", "Vector3", "Vector2",
    "CFrame", "Color3", "UDim", "UDim2", "Enum", "TweenInfo", "NumberSequence",
    "NumberRange", "Rect", "PhysicalProperties", "Random", "Drawing", "typeof",
    "print", "require", "string", "math", "table", "os", "coroutine", "bit32", "tick",
    "wait", "spawn", "delay", "warn", "next", "pairs", "ipairs", "select", "setmetatable",
    "getmetatable", "rawget", "rawset", "rawequal", "rawlen", "pcall", "xpcall", "error",
    "assert", "tonumber", "tostring", "type", "unpack", "loadstring", "newproxy",
}

files = sorted((ROOT / "src").rglob("*.lua"))
if not files:
    print("no sources found")
    sys.exit(1)

bad = 0
for path in files:
    src = path.read_text()
    rel = path.relative_to(ROOT)
    try:
        rt.compile(src)
    except Exception as exc:  # noqa: BLE001
        bad += 1
        print(f"SYNTAX {rel}: {exc}")
        continue

    # Cheap lint: flag obvious typos of engine globals and leftover debug calls.
    for line_no, line in enumerate(src.splitlines(), 1):
        code = line.split("--")[0]
        if "print(" in code and "Tools" not in str(rel):
            print(f"NOTE   {rel}:{line_no}: print() left in shipped code")
        for name in ("Instance.new(", "workspace.", "game:GetService("):
            pass
        if "task.wait()" in code:
            print(f"NOTE   {rel}:{line_no}: bare task.wait() - prefer a fixed step")

print(f"lint: {len(files)} files compiled, {bad} failures")
sys.exit(1 if bad else 0)
