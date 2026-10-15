# Inner Sun style guide

One voice and one look for everything in the game. The art section is written after the M1 art
bake-off picks a style. The voice section below is the law for every line of game text: events,
codex, TOPSIDE's radio, store blurbs, crew barks, the death screen.

## Voice

**The pitch in one breath:** pulp adventure with a conspiracy streak. Journey to the Center of the
Earth meets The X-Files. Wonder, danger, paperwork. The world below is real and astonishing; the
people above know more than they say.

### The three registers
1. **The dossier (events).** Second person, present tense, like a field report someone is typing as
   it happens. Plain, concrete, sensory. "The drill breaks into a pocket of still air that smells of
   wet pennies." Short sentences. One striking detail beats three adjectives.
2. **TOPSIDE (the handler, on the radio).** Terse, dry, careful. Never answers a question directly.
   Uses procedure and code words ("Copy, Auger. Log it and keep moving."). Very occasionally a line
   slips and says too much, then corrects itself. Never warm, never cruel. The crew's call sign is
   **Auger**.
3. **The crew.** Practical people doing a strange job. Gallows humor, short barks, no speeches.
   They swear in mild, period-neutral ways ("hell", "damn", never slurs).

### Rules
- **Never use an em dash.** Use a comma, a colon, a period or a spaced hyphen. The data lint rejects
  em dashes in game text.
- **Short.** Event pages 40 to 90 words. Options at most 12 words, in the imperative ("Cut the
  casing open."). Codex entries 60 to 140 words. Radio lines one or two sentences.
- **Hint, do not spell out.** An option says what you do, never the odds or the reward. The outcome
  page says what happened in the world first, then the numbers appear in the UI, not the prose.
- **Concrete over cosmic.** Name the material, the gauge, the smell, the depth in meters. Wonder
  comes from specific strangeness (a fossil fern that is still green), not from words like
  "eldritch" or "unspeakable".
- **Humor is understated.** A dry aside, a bureaucratic detail in a terrifying moment ("The intake
  form has a box for this. It is unchecked."). Never winking at the player, no memes, no modern
  slang.
- **Real history is found, never stated.** Byrd's 1947 flight, the Kola Superdeep Borehole and its
  "well to hell" legend, Project Mohole: they appear only as things the crew finds (tapes, plaques,
  core canisters, log books) and as codex entries. Present legends as legends. Never claim the real
  people did what the game invents.
- **Original work only.** No names, lines or situations from FTL, Barotrauma or any other game or
  book. No real living people.
- **Metric, always.** Meters, degrees C, kilograms.

### Redactions (the codex that lifts)
Text can hide words until the player's codex knows them:
`[[<codex id>:<hidden words>]]`. Unknown, it renders as black bars the length of the words; known
(the profile learned it on an earlier run, or this run did), the words show through. Use at most two
per page, on the nouns that matter: a place, a project, a name. A redaction should make the reader
want to know, and the codex entry should pay it off.

`{crew}` in text is replaced by the name of the crew member the event picked (the first live crew
member, unless the event says otherwise).

### Example lines
- Dossier: "The bit punches through into a gallery of white crystal, each blade taller than the
  tower. Your floodlights go in and do not come back out."
- TOPSIDE: "Auger, TOPSIDE. That reading is a calibration fault. Recalibrate and disregard."
- TOPSIDE slipping: "Do not open the - Disregard. Proceed at your discretion."
- Crew: "Coolant's at a third. Somebody tell me that's a lot."

## Look

**Chosen in the M1 bake-off (2026-10-15): painted pulp illustration**, generated with Gemini image
models through `pipeline/painted_gen.py`, processed by `pipeline/style_post.py`, lit in Godot with
scripted normal maps (`pipeline/normals.py`). Comparison: `docs/progress/005_m1-art-bakeoff.jpg`.
Provisional until Stewart has seen it; pixel art was not tried (no PixelLab key) and the Blender
pipeline (`pipeline/blender/`) stays as the fallback for anything that must turn or animate in many
consistent poses.

### The rules
- **Painted, not photographed.** Gouache and oil brushwork with confident strokes and a strong
  value structure, like a 1970s pulp magazine cover. Never photoreal, never glossy CG.
- **Palette.** Dark and moody: cold blue-grey steel and rock, warm amber and brass accents, hazard
  yellow and black, CRT green for readouts, alarm red only for alarms, fire orange only for fire.
  The rock gets colder and stranger as layers go down; the inner world is where color finally
  blooms.
- **Hardware.** 1970s black-budget retro-futurism: riveted plate, enamel and brass gauges, chunky
  switches, cable trays, stenciled labels (no readable real brand names), grime, scorch marks,
  patched welds. Everything looks built by a government contractor in a hurry.
- **Flat light in the art, real light in the game.** Assets are painted evenly lit, orthographic
  side view, no cast shadows, no vignette, no perspective: Godot's lights do the drama. Shapes must
  read at game scale (a room is 320 x 240 px at 1080p).
- **Production.** Generated at 160 px per meter and shown at 0.5 with linear filtering and mipmaps.
  Every asset is cut out on flat magenta, graded to the shared brightness target, and gets a scripted
  normal map (silhouette bevel, cylinder roll for round props, band-passed detail) and, where it
  glows, a separate emission sprite whose modulate is divided by the CanvasModulate color.
- **People.** Characters are drawn as one painted figure per crew member in strict side view, then
  cut into parts (head, torso, upper and lower arms, legs) and animated as cut-out puppets with
  Godot's 2D skeleton (Polygon2D and Bone2D): walk, climb, work, fight fire, hurt, fall. Faces are
  simple and readable; each crew member gets a distinct silhouette and color accent.
- **Consistency.** One shared style prompt (`STYLE` in `pipeline/painted_gen.py`) for everything,
  several variants per asset, the lead picks; every prompt, model and seed in
  `pipeline/manifests/`. A new asset that does not sit next to the bake-off reactor room without
  standing out gets regenerated.
- **Documents.** The dossier, codex and store use paper: typewriter text, rubber stamps, paper clips,
  redaction bars, coffee rings, on the same palette.

## Event files (the format the writer fills)

One event per file in `game/data/events/<id>.json`, checked by the data lint (`Encounter.lint`):

```json
{
  "id": "kola_tapes",
  "kind": "event",
  "layer": "crust",
  "rows": [1, 7],
  "weight": 1.0,
  "once_per_run": true,
  "title": "Reel Seven",
  "file": "FIELD REPORT 14-K // AUGER",
  "start": "intro",
  "pages": {
    "intro": {
      "text": "Page text with an optional [[codex_id:redaction]] and {crew}.",
      "radio": "Optional TOPSIDE line shown beside the page.",
      "options": [
        {
          "text": "Imperative option text.",
          "requires": {"res": {"gems": 5}, "system": {"helm": 2}, "skill": {"repair": 1.2}, "codex": "kola_well"},
          "outcomes": [
            {"weight": 3, "page": "good", "effects": [{"type": "res", "res": "ore", "amount": 8}]},
            {"weight": 1, "page": "bad", "effects": [{"type": "hull", "amount": -3}]}
          ]
        }
      ]
    },
    "good": {"text": "A page without options ends the event (the UI shows Continue)."}
  }
}
```

- `kind`: `event` (dossier node), `cavern` (salvage node), `hazard` (hazard node), `recruit`.
- `requires` (all optional, all must hold, otherwise the option shows greyed out with the reason):
  `res` (at least these amounts), `system` (at least these effective bars), `skill` (some live crew
  member has at least this skill), `codex` (known).
- An outcome without `page` ends the event after its effects.
- Effects:
  `{"type": "res", "res": <resource>, "amount": n}`,
  `{"type": "res_range", "res": <resource>, "min": a, "max": b}` (rolled from the run's event stream),
  `{"type": "hull", "amount": n}`,
  `{"type": "crew_damage", "target": "picked" | "random" | "all", "amount": hp}`,
  `{"type": "crew_join", "pool": <crew pool id>}`,
  `{"type": "crew_lose", "target": "picked" | "random"}`,
  `{"type": "fight", "enemy": <ship id>}`,
  `{"type": "hazard", "kind": "fire" | "breach" | "heat", "room": "random" | "system:<system>", "level": x}`
  (fire level 0 to 1, breach size in square meters, heat in kilojoules),
  `{"type": "system_damage", "system": <system>, "bars": n}`,
  `{"type": "codex", "id": <codex id>}`,
  `{"type": "pursuer", "rows": x}` (positive brings it closer),
  `{"type": "reveal", "rows": n}` (the scanner sees further for the rest of the layer),
  `{"type": "store", "store": <store id>}`.

Codex entries: `game/data/codex/<id>.json` with `id`, `title`, `category` (`history`, `place`,
`creature`, `tech`, `topside`), `text`, and `teaser` (one line shown on the death screen when it is
learned).
