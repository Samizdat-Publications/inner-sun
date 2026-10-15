# Spec: the M1 run screen (view side)

For builder agents, split into pieces with disjoint files. Read CLAUDE.md, docs/ARCHITECTURE.md
(view rules), docs/STYLE_GUIDE.md (voice; the Look section once the bake-off is done) and the sim
modules each piece reads. The view only reads the sim; every player action is a command
(`sim.push`). Pause (Space) stops calling `sim.step()`.

## Layout at 1920x1080 (scales with the window; canvas_items stretch)
```
+--------------------------------------------------------------------------------------------+
| HULL ######----  ORE 12  GEMS 30  COOLANT 18  CELLS 7  BITS 2  CHARGES 4    DEPTH 412 m      |  top bar
| PURSUER [=====>.........SHIP]                                               T+04:12  ||    |
+------------------+------------------------------------------------+------------------------+
| POWER            |                                                | SEISMIC SCANNER         |
|  reactor 8       |                                                |  (green CRT: rock ahead |
|  [helm   ##.. ]  |        the world view: the tower cutaway       |   30 m, ore, hard rock, |
|  [bracing##   ]  |        in the rock (or both ships in combat)   |   water, the heading)   |
|  [drill  ##.. ]  |                                                +------------------------+
|  [coolant##.  ]  |                                                | CREW                    |
|  [weapons...  ]  |                                                |  card: name, HP, job,   |
|                  |                                                |  station, skills        |
+------------------+------------------------------------------------+------------------------+
| alerts strip: FIRE in Drill Room / BREACH in Weapons / DRILL ROOM 96 C / BIT WORN            |
| combat only: weapon cards with charge bars and target                                         |
+--------------------------------------------------------------------------------------------+
```
- The world view fills the middle. The tower is drawn big (about 80 px per meter at 1080p) with
  about 4 m of rock visible below the crown; the scanner shows what is further ahead. Combat zooms
  out so both towers fit with rock between them.
- Overlays (modal; the sim is frozen in these phases anyway): the node map (M, or automatic in
  idle), the dossier (events), the store, the death screen with codex, the codex browser.

## Pieces (one builder each, disjoint files)
1. **Run main and camera** (`game/view/main.gd` modes, `game/view/run_view.gd`, camera framing per
   phase, pause, input to commands: click a room to send the selected crew member, keys 1 to 3 to
   select crew, A and D or the mouse on the scanner to steer, Space pause, M map). Main keeps the
   scenario mode for captures and tests; `--mode=run` (the default for normal play) starts a run.
2. **Rock view** (`game/view/rock_view.gd`): draws DrillSim's grid in chunk textures (16 x 16
   cells), redraws only chunks whose change counter moved, strata tinted, ore and gems glinting
   (small emission sprites), water pockets dark and wet, the shaft behind the tower, hull floodlights
   on the rock, one LightOccluder2D per solid chunk outline (rebuilt when the chunk changes), the
   drill face glow and sparks while cutting. Keeps lights per canvas item under 15.
3. **HUD panels** (`game/view/hud/*.gd`): top bar, power panel (click a bar to add or remove power:
   the `power` command), crew cards, alerts strip, scanner panel (reads the grid ahead), weapon cards
   in combat. One font family for instruments (a monospace with character, OFL licensed), one
   typewriter face for documents; both credited in docs/CREDITS.md.
4. **Overlays** (`game/view/overlay/*.gd`): node map (vertical, rows top to bottom, links, unknown
   nodes as "?", the pursuer shadow creeping down, click a linked node to choose it), dossier
   (typewritten page, file header, stamp, redaction bars that lift for known codex, options with
   greyed requirements), store, death screen (cause, depth, what was learned, codex teasers), codex
   browser.

## Quality bar (the blind critic reads this)
- Readability first: at a glance, which room burns, floods or overheats, who is where, what is
  powered, how close the pursuer is.
- No debug text in play. Room labels never overlap ladders. Water is a filled body, not a line.
  Damage flashes on crew. Crew draw above floors when climbing.
- Everything that changes also animates: bars ease, alerts pulse, the scanner sweeps.
