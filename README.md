# Inner Sun (working title)

An FTL-style roguelite about a drill ship boring down into a hollow Earth. You command the crew of a
tall drilling tower: split the reactor's power between systems, keep the heat down, put out fires,
patch floods, and choose your route down through layers that get stranger the deeper you go. At the
very bottom is the answer to a modern mystery.

This repository is built mostly by Claude, autonomously. Stewart owns it and plays it.

## Where things stand

Milestone 1, "find the fun", is iterating on Stewart's playtests: one layer (the Crust), a node map,
hands-on drilling where every system has a job (side cutting, rockfalls, blasts, douse), ore and gems
that buy gear, buried structures to break into, rival drill crews to fight, events, stores, and
research that buys starting equipment for the next run. Playtest build 4 is the latest. See
`PROGRESS.md` for details.

## Play it

Double-click `Play Inner Sun.bat` in this folder, or paste this into Windows PowerShell:

```powershell
cd "C:\Users\stewa\Documents\Claude\Inner Sun"; & "C:\Users\stewa\Documents\Claude\Inner Sun\Play Inner Sun.bat"
```

It starts a new run. Close the window to quit (an unfinished run is saved too). If the keys do
nothing at first, click once inside the game window to give it the keyboard.

### How to play (one page)

You command the drill tower **Auger**, boring down through the Crust toward the layer gate. Each run
is one descent. Dying is normal: what you learn goes into the codex and lifts redactions next time.

- **The map.** Between stops the node map opens. Click one of the lit nodes below you to drill there
  (it costs one power cell). Icons show what is there: event, cavern (salvage), hazard, store, fight,
  the gate, and the rich deposit (a gem icon: a known rich seam). Nodes inside your scanner range show
  what the rock on the way to them holds: gold pips for richness, coloured squares for the ores, diamonds
  for the gems, a yellow flame for gas pockets and a blue drop for water pockets (hover a node for it in
  words). Nodes past your scanner show as "?". The dark front creeping down from the top is the
  thing that follows your noise: nodes it swallows are lost, and if it reaches you it strikes the hull.
  Press **M** to open or close the map. Time stands still while the map is open; you can still give
  orders from it.
- **Drilling.** **A** and **D** (or the arrow keys) turn the drill 15 degrees a press (hold to keep
  turning), **S** points it straight down again, and **Shift+A** or **Shift+D** holds depth: the tower
  cuts sideways along a vein. You can also click on the seismic scanner (top right), which shows the
  rock ahead: ore veins, gem pockets, hard rock, water pockets, fault rock and buried structures. More
  drill power is faster, hotter and louder; more helm power (with someone at the bridge) turns faster
  and cuts sideways faster. Detour for ore and gems, or go straight and stay ahead of the front. A worn bit slows you down: press **B** (or click the button on the scanner) to fit a new one.
  The scanner colours each ore and gem as the rock does (a legend runs along its foot); gas pockets are
  yellow-green and water pockets blue. Whatever the crown cuts floats up as "+2 IRON", "+5 EMERALD"
  (bigger for gold and gems), a line at the top of the world shows the dig so far, and a plaque sums
  up the segment on arrival. The mouse wheel zooms the drilling view.
- **Blast.** While drilling, the charge launcher's weapon key (**F2** on the starting ship) or the BLAST
  card at the bottom left arms it;
  click the rock (in the view or on the scanner, up to 14 m away) to blast it. It needs a bar in
  weapons and costs a charge. A blast cracks hard shells, burns off gas pockets and drains water
  pockets before you reach them, but shatters half the ore it frees: cutting a vein yourself pays all
  of it.
- **Away miner.** While drilling, **G** (or the SEND MINER card next to the blast card) arms the order for
  the crew member selected on the crew cards (1 to 3); click the rock or the scanner within 12 m of the
  drill head to send them. They climb out and dig a tunnel by hand to the spot, mine out the vein there
  at full yield and walk home. The drill parks until they are back, and the front keeps coming. They are
  not aboard to man stations or fight fires, and gas, water and fault rock hurt them. What they carry
  pays only when they climb back in, and is lost if they die. **G** again recalls them; **Esc** or a
  right click cancels the aim.
- **Fault rock.** Pale cracked rock drops rockfalls on the top deck while you cut it. Each bracing
  layer (two bars in **W**) soaks one; without one you lose hull and a top room is damaged.
- **Buried structures.** Old mine works, a Soviet rig module, a crystal hollow: break in for crates of
  loot, a codex entry, sometimes an event or a trader. The map shows which routes pass one.
- **Power.** The panel on the left splits the reactor's bars between systems. Click a bar, or press
  **Q W E R T** to add a bar to helm, bracing, weapons, drill, coolant (hold **Shift** to remove
  one). Damaged bars are crossed out; overheated systems stop working. Power comes back by itself
  after a repair.
- **Heat, fire, water.** Deeper rock is hotter. Coolant keeps rooms survivable and is used up as it
  works (buy more in stores). Fires spread and water pools in the bottom deck: the crew handle
  emergencies on their own when idle. **F** (or the DOUSE button on a burning room) vents one unit of
  coolant onto the worst fire; it needs a bar in coolant and pumps.
- **Crew.** Press **1**, **2**, **3** (or click a crew card) to select someone, left-click a room to
  send them there, right-click to let them go back to their own judgement. Someone at the bridge makes
  the ship harder to hit and steer faster.
- **Pause.** **Space** pauses and unpauses. You can give orders while paused (power changes show as
  blinking bars until time moves). The game also pauses by itself when a fight starts.
- **Help.** **H** (or the HELP chip at the top right) opens the help page, which it also does on your
  very first run. **Esc** or **H** closes it.
- **Events.** Read the dossier and click an option (or press its number). Greyed options say what
  they need: the power keys still work while a dossier is open, so you can give it the bars it asks for.
- **Store.** Every line shows its price with the ore or gem icon it is paid in (red when you are short).
  Ore buys refits, hull repairs and gear (drill heads, hull plating, pumps; a line says what the gear
  changes and what it replaces); gems buy coolant, cells, bits, charges, a weapon or a new crew member. **Esc** leaves.
- **Fights.** When a rival rig attacks, its tower appears beside yours. Put power into weapons
  (**E**) and bracing (**W**), take some from the drill (**Shift+R**). Press **F1** or **F2** (or click a
  weapon card at the bottom) to arm a weapon, then click an enemy room to aim it: it fires by itself
  whenever it is charged. Bracing stops borer rounds; mining charges ignore bracing but use ammo.
  Right-click a card to stop firing. **FLEE** digs you out (it needs 2 drill bars and someone at the
  bridge).
- **The end.** The report shows how deep you got, what killed you and what you learned, and the
  research the run earned. **Requisitions** (**R**) spends research on equipment loaded onto every later
  dive (spare bits, charges, coolant, plating, a tungsten head, a fourth crew member). **New run**
  starts again.

Every run you play is saved for bug hunting in `%APPDATA%\InnerSun\runs\` (paste that into the
Windows Explorer address bar to open it). If something goes wrong, note the time: Claude can replay
that exact run.

## Start the next build session

The exact prompt and settings are in `HANDOFF.md` ("Start the next session"). In short: open the
Claude app, Code tab, new session in `C:\Users\stewa\Documents\Claude\Inner Sun`, model Opus 5.5,
effort xhigh, permission mode Auto, then paste the prompt from `HANDOFF.md`.

## Where to look

| File | What it is |
|---|---|
| `PROGRESS.md` | Current milestone, what is done, what is next |
| `PLAN.md` | The approved plan: design, decisions, milestones, content roadmap, risks |
| `HANDOFF.md` | How a fresh session picks up the work |
| `docs/STEWART_FEEDBACK.md` | Your notes and decisions; they outrank everything else |
| `docs/progress/` | Progress pictures, in order |
| `docs/research/godot-loop.md` | The Milestone 0 proof, with evidence |
| `docs/SPEND.md` | Every paid AI generation and its cost |

## Running two Godot games at once

Inner Sun and Black Diamond can both run Godot on this PC at the same time. If you notice the PC
getting slow, closing Chrome tabs and Notion frees the most memory. The rules both projects follow
are in `C:\Users\stewa\Documents\Claude\GODOT-SIDE-BY-SIDE.md`.
