# Inner Sun (working title)

An FTL-style roguelite about a drill ship boring down into a hollow Earth. You command the crew of a
tall drilling tower: split the reactor's power between systems, keep the heat down, put out fires,
patch floods, and choose your route down through layers that get stranger the deeper you go. At the
very bottom is the answer to a modern mystery.

This repository is built mostly by Claude, autonomously. Stewart owns it and plays it.

## Where things stand

Milestone 0 is done. It proved that the build loop works without anyone at the keyboard: the game runs
headless and with a window, a bot plays it, frames come from the game camera, tests catch planted
bugs, thousands of runs play out for balance, and the exported game gives the same results as the
editor. What you can see today is a test scene: a fire drill on the starting ship, with placeholder
art. Milestone 1 builds the first playable slice. See `PROGRESS.md` for details.

## Play the M0 test scene

Double-click `Play Inner Sun.bat` in this folder, or paste this into Windows PowerShell:

```powershell
cd "C:\Users\stewa\Documents\Claude\Inner Sun"; .\"Play Inner Sun.bat"
```

A fire breaks out in the drill room and the hull breaches on the middle deck; a scripted bot sends
the crew. Click a room to send the first crew member there yourself. Close the window to quit.

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
