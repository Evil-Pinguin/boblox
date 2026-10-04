# BLACKSITE

A co-op horror experience for Roblox, written as plain source in this repo.

You wake up in the sub-level of a facility that has already been decommissioned. Five
igniter cells are still charged and scattered somewhere in the dark below. Something
else is down there with them. It navigates by sound and by what it can see through the
corridors; your flashlight finds it just as reliably as it finds the cells, and it is
bright enough that running with it on is a gamble, not a tactic. Get the cells, get to
the gate, get out before the purge cycle finishes. Three lives, per person, per round.

```
21 x 21 procedurally generated maze    darkness + a flashlight with real battery drain
stalking entity with sound + LOS AI     lockers to hide in (it can drag you out)
noise model: sprint > walk > crouch      bandages, spare cells, a 6-minute purge timer
round loop with lobby + results          dread-driven blur, vignette, glitch bars, shake
```

---

## Play it in Studio (no installs)

`Blacksite.rbxlx` is a complete, ready-to-open place file.

1. Open Roblox Studio.
2. **File → Open from File…** and pick `Blacksite.rbxlx`.
3. Press **Play**. The lift waits for one volunteer, so click the menu.

All world geometry is built by the server at runtime, which is why the place file is
mostly scripts. Nothing in it depends on uploaded assets, so it works offline, in any
group, and in a fresh baseplate.

Regenerate the place file after editing sources:

```bash
python3 tools/build_place.py
```

## Play it with Rojo (recommended for editing)

`default.project.json` maps the tree the way Rojo expects:

| Source | Destination in Studio |
| --- | --- |
| `src/shared/*.lua` | `ReplicatedStorage.Blacksite` (ModuleScripts) |
| `src/server/*.lua` | `ServerScriptService.Blacksite` (`*.server.lua` → Script, rest → ModuleScript) |
| `src/client/*.lua` | `StarterPlayer.StarterPlayerScripts.Blacksite` (`*.client.lua` → LocalScript) |

```bash
rojo serve            # from this folder
rojo build -o Blacksite.rbxlx
```

Studio plugin: **Plugins → Rojo → Connect**. Then **Play** in the solo test server.

## Controls

| Key | Action |
| --- | --- |
| `E` (prompts) | Pick up a cell / battery / bandage, enter and leave a locker, work the gate |
| `F` | Flashlight on/off. It also lights the Hollow: your beam is a targeting line as much as a tool |
| `LeftShift` | Sprint. Loud (84 studs of noise), burns stamina |
| `LeftCtrl` | Crouch. Quiet (11 studs), slow, and it regenerates stamina faster |
| `V` | First/third person. `M` mutes the audio you have configured |
| mobile | On-screen LIGHT / RUN / SNEAK buttons are bound at the same handlers |

Sprinting near the Hollow is a death sentence; crouching out of sight is not. The only
difference is the noise you emit. Nothing in the HUD tells you how loud you are being -
the signal bar points at the nearest objective - so the tell is the dread: the blur at
the edges of the screen, the shake, and the heartbeat if you have configured one.

## Architecture

```
src/shared/
  Config.lua       every tunable number, colour and string in the game
  MazeGen.lua      pure-Lua generator: braided maze + rooms, LOS raycast, BFS flow fields
  Util.lua         clamp / damp / lerp / distance helpers
  Remotes.lua      exactly two RemoteEvents: client->server Action, server->client Event
  Attributes.lua   write-only-if-changed attribute helper (the replication channel)
src/server/
  Init.server.lua  services, Lighting/Atmosphere, spawn, the Heartbeat beat
  MapBuilder.lua   turns a MazeGen grid into parts, prompts, lockers, lamps, the gate
  Entity.lua       the Hollow: 20 Hz brain (perception, routing, state), 60 Hz motion
  Round.lua        the director: phases, spawns, scoring, deaths, purges, results
src/client/
  Init.client.lua  glue: input, sound, remote dispatch, one RenderStepped for all updates
  HUD.lua          every pixel of UI, built in code (objective, meters, compass, menu, results)
  Effects.lua      post-processing + overlay: blur, vignette, glitch bars, fades, tint
  Rig.lua          camera: dread floor + impulse shake, speed bob, FOV, turn sway
  Flashlight.lua   the beam, its flicker curve, and the battery that drives both
```

Two rules make this shape work, and they are worth keeping if you extend it:

- **State flows through attributes.** The server publishes `Dread`, `Battery`,
  `Hidden`, `Cells` and friends on each `Player`, and round state on
  `workspace.BlacksiteRoot`. Clients read them locally, so the HUD never waits on a
  remote round-trip. Remotes are reserved for *transient* things: toasts, hits, scares.
- **Anything a client creates lives under the Camera.** `Lighting`, `Workspace`,
  `SoundService` and `ReplicatedStorage` are FilteredEngine-safe to *read* from a
  client but writes to them either do not replicate or leak into your own session. So
  `Effects` parents its overlay and post-effects to `CurrentCamera`, and the flashlight
  carrier part is a client-local `Part` in Workspace that nobody else can see.

The Hollow's pathfinding is the maze's own BFS flow field (`MazeGen:flowField` +
`descend`), recomputed every 0.28 s while hunting, not `PathfindingService`. A grid
that small is cheaper, exact, and lets `lineOfSight` use the same structure the AI
walks on.

## Tuning

Everything below is in `src/shared/Config.lua`. None of it needs a rebuild: with Rojo
it hot-reloads, and in Studio it is one script open.

| Knob | Default | What it changes |
| --- | --- | --- |
| `World.CellsWide / CellsDeep` | 21 / 21 | Maze size. The grid is `2*cells-1` tiles; 41x41 tiles is ~490 studs across |
| `World.Braid` | 0.55 | How many dead ends become loops. 0 = perfect maze (brutal), 1 = wide open |
| `World.Rooms` | 6 | Large chambers carved in, so the map is not only corridors |
| `Round.Limit` | 360 | Seconds before the purge kills everyone still inside |
| `Round.PurgeWarn` | 60 | When the lamps go red and the entity speeds up |
| `Round.CellsNeeded` | 5 | Objective size. `CellsSpawned` above it adds decoys |
| `Round.Lockers` | 12 | Hiding spots. Fewer lockers makes the entity's chase far more lethal |
| `Player.Lives` | 3 | Per-person lives; the team loses when the last one is spent |
| `Player.BatteryDrain` | 3.1 | Percent per second. -3.1 is ~32 s of light per full cell |
| `Entity.Speeds.hunt` | 18.6 | Sprint is 27, so you can outrun it in a straight line - if you have stamina |
| `Entity.SightRange` | 96 | Studs of vision, gated by `FaceAngle` (100°) and real line of sight |
| `Entity.CloseSenseRange` | 34 | Inside this it tracks you through walls, so a locker two tiles away is not hiding |
| `Entity.KickInTime / KickRange` | 3.2 / 15 | While it is hunting *you*, that many seconds at your locker door drags you out for 20 damage |
| `Entity.EnragePerLife` | 1.35 | Speed added per life the *team* has burned, so a bad round gets shorter |
| `Noise.Sprint / Walk / Crouch` | 84 / 36 / 11 | Radius of the noise ping each gait emits |
| `Dread.Radius` | 105 | How early the blur/vignette/shake start creeping in |
| `Camera.Fov / SprintFov / HiddenFov` | 70 / 79 / 52 | The whole "speed" feel lives here |
| `Light.FlickerStart` | 28 | Battery percent where the beam starts to struggle |

Difficulty in one line, if you want it meaner: `SightRange = 120`, `Braid = 0.2`,
`Lockers = 6`, `BatteryDrain = 4.5`, `Limit = 240`.

## Sound

The game ships with **zero** audio ids on purpose - no external asset dependencies.
`Config.Sounds` is a table of empty strings and every call site is `pcall`-wrapped, so
pasting ids is the only step:

```lua
Config.Sounds = {
	Scream = "rbxassetid://1837871264",   -- the Hollow, on a grab
	Heartbeat = "rbxassetid://1842220265",
	Ambience = "rbxassetid://1836647771",  -- looping room tone
	...
}
```

`Heartbeat` is special: the client cross-fades its volume against the `Dread`
attribute, so it is already wired to get louder as the entity closes. `FootstepConcrete`
and `Sprint` fire on the same cadence the server uses to emit noise pings (0.44 s
walking, 0.30 s sprinting, 0.72 s crouching), so the sound of running is genuinely the
sound of being heard. `GateOpen`/`Alarm` come from the round director, `Win`/`Lose` from
the results screen, `LockerOpen`/`LockerClose`/`CellTaken` from the prompt handlers.

## Verifying without Studio

`tools/verify.py` runs the whole battery offline:

```bash
python3 -m venv .venv && .venv/bin/pip install lupa
.venv/bin/python tools/verify.py
```

```
lint: 14 files compiled, 0 failures
MazeGen: 27067/27067 checks passed
Round simulation: 38/38 checks passed
Client simulation: 37/37 checks passed
wrote Blacksite.rbxlx (174.5 KB) ... referents unique, xml valid
```

What each one is for:

- `tools/lint.py` compiles every source file with a strict Lua parser. The project
  deliberately avoids Luau-only syntax (type annotations, `continue`, string
  interpolation, `//`) so this is a real check rather than a lint of convenience - and
  so the pure-logic modules stay testable outside the engine.
- `tools/test_maze.py` asserts the generator's invariants: every cell reachable, no
  sealed sub-regions, LOS agrees with the grid, flow fields always descend toward the
  goal, pickups land on walkable tiles.
- `tools/simulate_round.lua` boots the **real server scripts** inside
  `tools/mock_roblox.lua` (a small headless Roblox engine: Instances, signals,
  attributes, `TweenService`, `task`, deferred binds) and plays two rounds with three
  fake crew - collecting cells through their actual `ProximityPrompt` objects, standing
  under the entity to be grabbed, dying, respawning, hiding, escaping, getting left
  behind, and reading back the resulting attributes and remote traffic.
- `tools/simulate_client.lua` boots the **real client scripts** against that server and
  checks that the HUD, menu, results panel and `ContextActionService` bindings come up,
  that server events reach the labels, that a configured sound id actually produces
  playback, and that no client-only instance ends up in a replicated service.

This is how the project found its bugs so far, and it earns its keep: the mock caught a
method shadowed by an instance field of the same name, a shared-module `require` that
resolved to the wrong folder, a spawn path that only worked when `LoadCharacter`
finished synchronously, an input throttle that swallowed the first action of every
session, a respawn handler that indexed the nil character `CharacterRemoving` passes,
and a `pcall` that had been quietly hiding all of it.

## Adding things

- **A new pickup kind**: `MapBuilder:addPickup` already takes a `kind`; add the kind's
  style in its table, then a branch in `Round:onPrompt`. `takePickup` handles the
  destroy/noise/toast side for you.
- **A new entity state**: `Entity:setState` plus a case in `Entity:plan`'s goal
  choice. `computeDread` decides how the client feels about it.
- **A second monster**: `Round:begin` builds one `Entity`; the module takes a `round`
  and a `level`, so a second instance works if you give it its own `Name` (the model,
  `TheHollow`, is looked up by name for the reveal highlight).
- **Map themes**: `Config.World` colours/materials plus `MapBuilder:buildFloorAndRoof`.

## Licence

Whatever the rest of this repo uses.
