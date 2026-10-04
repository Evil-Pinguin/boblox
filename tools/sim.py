#!/usr/bin/env python3
"""Run the headless gameplay simulation in tools/simulate_round.lua.

Assembles one Lua program: the mock engine, the real server sources registered into
the right services, then the scenario. Any Lua error aborts with a traceback, which is
how this catches nil-index and typo bugs that a syntax check cannot see.

    python3 tools/sim.py            # full round simulation
    python3 tools/sim.py --quiet    # only the final summary lines
"""
from __future__ import annotations

import pathlib
import sys

import lupa

ROOT = pathlib.Path(__file__).resolve().parent.parent

DELIM = "[==["
END = "]==]"


def lit(text: str) -> str:
    """Embed a Lua source file as a long-bracket string literal."""
    if DELIM in text or END in text:
        raise SystemExit(f"source contains the long-bracket delimiter: {END}")
    return f"{DELIM}{text}{END}"


def class_for(name: str) -> str:
    if name.endswith(".server.lua"):
        return "Script"
    if name.endswith(".client.lua"):
        return "LocalScript"
    return "ModuleScript"


def name_for(fname: str) -> str:
    for suffix in (".server.lua", ".client.lua", ".lua", ".luau"):
        if fname.endswith(suffix):
            return fname[: -len(suffix)]
    raise ValueError(fname)


def sources(rel: str) -> list[tuple[str, str, str]]:
    out = []
    for path in sorted((ROOT / rel).rglob("*.lua")):
        text = path.read_text(encoding="utf-8")
        out.append((class_for(path.name), name_for(path.name), text))
    return out


def main() -> int:
    quiet = "--quiet" in sys.argv

    program = [
        "local mock = (function()\n" + (ROOT / "tools/mock_roblox.lua").read_text() + "\nend)()",
        "_G.MOCK = mock",
        "mock.boot()",
        "",
        "-- register shared modules (ReplicatedStorage.Blacksite)",
    ]

    for cls, name, text in sources("src/shared"):
        program.append(f'mock.register("ReplicatedStorage", "{cls}", "{name}", {lit(text)}, "Blacksite")')

    program.append("-- server modules first, then the entry Script so the order matches Rojo")
    for cls, name, text in sources("src/server"):
        if cls == "Script":
            continue
        program.append(f'mock.register("ServerScriptService", "{cls}", "{name}", {lit(text)}, "Blacksite")')

    boot = None
    for cls, name, text in sources("src/server"):
        if cls == "Script":
            boot = (name, text)
            break
    if boot is None:
        raise SystemExit("no Init.server.lua found")

    with_client = "--client" in sys.argv
    program.append("-- run the server")
    program.append(f'mock.runScript("ServerScriptService", "{boot[0]}", {lit(boot[1])}, "Blacksite")')

    if with_client:
        # The client reads Players.LocalPlayer at load time, so the fake player has to
        # exist before the LocalScript runs.
        program.append('local tester = mock.newPlayer("Tester", 99)')
        program.append('tester.Parent = game:GetService("Players")')
        program.append('game:GetService("Players").PlayerAdded:Fire(tester)')
        program.append("-- client modules live under StarterPlayerScripts.Blacksite, as Rojo puts them")
        for cls, name, text in sources("src/client"):
            if cls == "LocalScript":
                continue
            program.append(f'mock.register("StarterPlayer", "{cls}", "{name}", {lit(text)}, "StarterPlayerScripts", "Blacksite")')
        entry = None
        for cls, name, text in sources("src/client"):
            if cls == "LocalScript":
                entry = (name, text)
                break
        if entry is None:
            raise SystemExit("no Init.client.lua found")
        program.append("-- run the client")
        program.append(f'mock.runScript("StarterPlayer", "{entry[0]}", {lit(entry[1])}, "StarterPlayerScripts", "Blacksite")')
    scenario = "tools/simulate_client.lua" if "--client" in sys.argv and "--scenario" not in sys.argv else "tools/simulate_round.lua"
    if "--scenario" in sys.argv:
        scenario = sys.argv[sys.argv.index("--scenario") + 1]
    program.append("-- run the scenario")
    program.append((ROOT / scenario).read_text())

    src = "\n".join(program)
    if not quiet:
        print(f"sim: {len(src.splitlines())} lines of Lua assembled")

    rt = lupa.LuaRuntime()
    # A real Lua 5.x interpreter, so line numbers in tracebacks point at our sources.
    try:
        rt.execute(src)
    except Exception as exc:  # noqa: BLE001
        print("SIMULATION FAILED")
        print(exc)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
