# Critic ledger

Every issue a critic raises: FIX (then fix it), DEFER (to which milestone) or REJECT (with a real reason).
A rejected issue that returns in 2 later critiques becomes FIX or goes to docs/NEEDS_STEWART.md.

| # | Build | Critic | Issue | Verdict | Commit or reason |
|---|---|---|---|---|---|
| 1 | 20261015-183051-e2dc572 | claude 001 | Debug overlay instead of a UI; cannot tell what I may do | FIX | M1 step 3 to 5: real HUD (power bars, crew cards, alerts) replaces the M0 readout |
| 2 | 20261015-183051-e2dc572 | claude 001 | Ship is a small box in a black void; cutaway should fill the frame | FIX | M1 step 1: camera framing for drilling and idle; tower plus rock fills the screen |
| 3 | 20261015-183051-e2dc572 | claude 001 | No world outside the hull: no strata, depth or heat | FIX | M1 step 1: drilling segment, chunked rock with strata, ore, water pockets, drill face glow |
| 4 | 20261015-183051-e2dc572 | claude 001 | Rooms interchangeable, no props or system identity | FIX | M1 step 2: system props per room in the chosen art style, plus system icons in the HUD |
| 5 | 20261015-183051-e2dc572 | claude 001 | Crew are placeholder dolls and clip through floors on ladders | FIX | Draw order bug: crew must draw above floor frames while climbing; crew sprites from the art bake-off |
| 6 | 20261015-183051-e2dc572 | claude 001 | Overlapping labels, water line too thin to read, HP loss invisible on the body | FIX | View pass with the HUD: labels clear of ladders, filled water body, damage flash and HP pips |
| 7 | 20261015-183051-e2dc572 | claude 001 | Uniformly dark, brown on brown; only the fire is lit | FIX | Art bake-off and lighting pass (reactor glow, alarm cast, HDR glow) |
