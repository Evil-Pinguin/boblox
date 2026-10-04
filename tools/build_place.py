#!/usr/bin/env python3
"""Build a Roblox Studio place file (.rbxlx) from the Luau sources in src/.

Why this exists: it mirrors exactly what `rojo build` does with default.project.json
(folder -> instance, suffix -> script class), so the game can be handed to anyone as a
single file to double-click in Studio, with no toolchain to install. Keep both in sync;
the source tree is the truth and this file just projects it.

    python3 tools/build_place.py [output.rbxlx]

Class mapping (Rojo's convention):
    foo.server.lua  -> Script       named foo
    foo.client.lua  -> LocalScript   named foo
    foo.lua         -> ModuleScript  named foo
    foo.lua/bar.lua -> ModuleScript + Folder, so a folder of .lua files stays tidy
"""
from __future__ import annotations

import pathlib
import sys
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parent.parent

# (service, child folder name, source dir)
TREES = [
    ("ReplicatedStorage", "Blacksite", "src/shared"),
    ("ServerScriptService", "Blacksite", "src/server"),
    ("StarterPlayer", "Blacksite", "src/client"),
]

# StarterPlayerScripts is where client scripts must live to survive respawns.
CLIENT_PARENT = "StarterPlayerScripts"


def class_for(name: str) -> tuple[str, str] | None:
    """Return (roblox class, instance name) for a source file name."""
    if name.endswith(".server.lua"):
        return "Script", name[: -len(".server.lua")]
    if name.endswith(".client.lua"):
        return "LocalScript", name[: -len(".client.lua")]
    if name.endswith(".luau"):
        return "ModuleScript", name[: -len(".luau")]
    if name.endswith(".lua"):
        return "ModuleScript", name[: -len(".lua")]
    return None


class Builder:
    def __init__(self) -> None:
        self.referent = 0

    def next_ref(self) -> str:
        self.referent += 1
        return f"RBX{self.referent}"

    def esc(self, text: str) -> str:
        # Only the three XML-significant characters matter inside ProtectedString;
        # Lua source is full of quotes and backslashes that must stay literal.
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    def prop(self, name: str, value: str) -> str:
        return f"<string name=\"{name}\">{self.esc(value)}</string>"

    def instance(self, cls: str, name: str, extra_props: str = "", children: str = "") -> str:
        ref = self.next_ref()
        props = self.prop("Name", name)
        if extra_props:
            props += extra_props
        out = [f'<Item class="{cls}" referent="{ref}">']
        out.append(f"<Properties>{props}</Properties>")
        if children:
            out.append(children)
        out.append("</Item>")
        return "".join(out)

    def script_item(self, path: pathlib.Path) -> str:
        mapping = class_for(path.name)
        assert mapping is not None
        cls, name = mapping
        source = path.read_text(encoding="utf-8")
        # Strip a BOM if anyone ever saves one; Studio chokes on it inside a script.
        source = source.lstrip("\ufeff")
        extra = f"<ProtectedString name=\"Source\">{self.esc(source)}</ProtectedString>"
        return self.instance(cls, name, extra)

    def tree(self, directory: pathlib.Path) -> str:
        """Recursively turn a directory of sources into nested Items."""
        items: list[str] = []
        for entry in sorted(directory.iterdir()):
            if entry.name.startswith(".") or entry.name.startswith("_"):
                continue
            if entry.is_dir():
                kids = self.tree(entry)
                if kids:
                    items.append(self.instance("Folder", entry.name, "", kids))
            else:
                if class_for(entry.name):
                    items.append(self.script_item(entry))
                else:
                    print(f"  skip (not a script): {entry.relative_to(ROOT)}")
        return "".join(items)


def build() -> str:
    b = Builder()
    chunks: list[str] = []
    chunks.append(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
    )

    counts: dict[str, int] = {}

    # --- content tree -----------------------------------------------------
    for service, folder_name, rel in TREES:
        src_dir = ROOT / rel
        inner = b.tree(src_dir)
        counts[service] = len(ET.fromstring(f"<r>{inner}</r>"))
        if service == "StarterPlayer":
            inner = b.instance(CLIENT_PARENT, CLIENT_PARENT, "", inner)
        chunks.append(
            f'<Item class="{service}" referent="{b.next_ref()}">'
            f"<Properties></Properties>{inner}</Item>"
        )

    # --- workspace: a spawn so the place is never empty, plus the root folder
    spawn = b.instance(
        "SpawnLocation",
        "BlacksiteSpawn",
        "<bool name=\"Anchored\">true</bool>"
        "<bool name=\"Neutral\">true</bool>"
        "<bool name=\"CanCollide\">false</bool>"
        "<float name=\"Transparency\">1</float>"
        "<float name=\"Duration\">0</float>"
        "<CoordinateFrame name=\"CFrame\">"
        "<X>0</X><Y>-119</Y><Z>0</Z>"
        "<R0>1</R0><R1>0</R1><R2>0</R2>"
        "<R3>0</R3><R4>1</R4><R5>0</R5>"
        "<R6>0</R6><R7>0</R7><R8>1</R8>"
        "</CoordinateFrame>"
        "<Vector3 name=\"size\"><X>24</X><Y>1</Y><Z>24</Z></Vector3>",
    )
    root_folder = b.instance("Folder", "BlacksiteRoot")
    chunks.append(
        f'<Item class="Workspace" referent="{b.next_ref()}">'
        f"<Properties><bool name=\"StreamingEnabled\">false</bool></Properties>"
        f"{spawn}{root_folder}</Item>"
    )

    # --- lighting defaults (the server re-applies these at runtime anyway)
    lighting_props = [
        "<float name=\"Brightness\">0</float>",
        "<float name=\"ClockTime\">0</float>",
        "<bool name=\"GlobalShadows\">true</bool>",
        "<float name=\"FogStart\">14</float>",
        "<float name=\"FogEnd\">118</float>",
        "<Color3 name=\"FogColor\"><R>0.024</R><G>0.027</G><B>0.035</B></Color3>",
        "<Color3 name=\"OutdoorFogColor\"><R>0.024</R><G>0.027</G><B>0.035</B></Color3>",
        "<Color3 name=\"Ambient\"><R>0.012</R><G>0.016</G><B>0.024</B></Color3>",
        "<Color3 name=\"OutdoorAmbient\"><R>0</R><G>0</G><B>0</B></Color3>",
        "<float name=\"EnvironmentDiffuseScale\">0</float>",
        "<float name=\"EnvironmentSpecularScale\">0</float>",
    ]
    chunks.append(
        f'<Item class="Lighting" referent="{b.next_ref()}">'
        f"<Properties>{''.join(lighting_props)}</Properties></Item>"
    )

    chunks.append("</roblox>")
    for service, count in counts.items():
        print(f"  {service}: {count} top-level children")
    return "".join(chunks)


def main() -> int:
    out = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "Blacksite.rbxlx"
    xml = build()

    # Never ship a place file that is not even well-formed XML.
    try:
        ET.fromstring(xml)
    except ET.ParseError as exc:
        print(f"generated XML is not well formed: {exc}", file=sys.stderr)
        (ROOT / "build" / "failed.rbxlx").parent.mkdir(exist_ok=True)
        (ROOT / "build" / "failed.rbxlx").write_text(xml, encoding="utf-8")
        return 1

    out.write_text(xml, encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size / 1024:.1f} KB)")

    tree = ET.fromstring(xml)
    items = list(tree.iter("Item"))
    kinds: dict[str, int] = {}
    for item in items:
        kinds[item.get("class", "?")] = kinds.get(item.get("class", "?"), 0) + 1
    print("  items:", len(items), "|", ", ".join(f"{k}={v}" for k, v in sorted(kinds.items())))
    refs = [i.get("referent") for i in items]
    assert len(set(refs)) == len(refs), "duplicate referents"
    print("  referents unique, xml valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
