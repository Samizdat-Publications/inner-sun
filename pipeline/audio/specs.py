"""Sound list: name -> prompt, duration_s, loop, synth kind. Prompts go to ElevenLabs; synth is the fallback."""
S = {}


def a(name, prompt, dur, loop=False, kind=None):
    S[name] = dict(prompt=prompt, dur=dur, loop=loop, kind=kind or name)


a("drill_motor_loop", "Heavy industrial electric motor and gearbox hum, steady low drone, 1970s machinery, no rhythm changes, seamless loop", 6, True)
a("grind_soft_loop", "Rotary drill bit grinding steadily through soft crumbly earth and clay, muffled, continuous, seamless loop", 5, True)
a("grind_hard_loop", "Heavy rotary drill bit grinding through hard rock, deep rough rumbling bite, continuous, seamless loop", 5, True)
a("grind_squeal_loop", "High metallic squeal of a drill bit screeching on very hard rock, steel on stone, continuous, no low rumble, seamless loop", 4, True)
a("drill_spin_down", "Large electric drill motor winding down to a stop, pitch falling, heavy machinery slowing, ends in silence", 2.5)
a("drill_spin_up", "Large electric drill motor starting up, pitch rising from a low thunk to a steady heavy whine, heavy machinery", 2.5)
a("pocket_burst", "Pressurized water pocket bursting violently into a steel room, sudden loud crack then gushing water hitting metal", 3)
a("water_rush_loop", "Water rushing and pouring into an enclosed steel chamber, steady flowing roar with splashing, seamless loop", 5, True)
a("fire_crackle_loop", "Small fire crackling and hissing in a metal room, steady burning, pops and flames, seamless loop", 5, True)
a("alarm_klaxon_loop", "Old electromechanical klaxon alarm horn, harsh two-tone blare, 1970s submarine style, repeating, seamless loop", 4, True)
a("hull_hit", "Heavy round cannonball striking a thick steel hull, deep booming metallic clang with resonant ring", 2.5)
a("bracing_absorb", "Hydraulic piston thud absorbing an impact, followed by a groaning metal creak, heavy machinery", 2.5)
a("borer_fire", "Mechanical gun-like bolt launcher firing, sharp pneumatic thump and a metallic clack, short", 1.5)
a("lance_fire_loop", "Continuous electric energy beam hum, buzzing humming plasma lance, low and steady, seamless loop", 4, True)
a("charge_fire", "A mining charge launched from a pneumatic tube, hollow thump and whoosh fading away", 1.8)
a("charge_explosion", "Underground mining charge explosion in rock, deep boom, rumble and falling debris", 3.5)
a("bit_change", "Ratchet wrench clicking several times followed by a heavy metal clunk of a drill bit locking into place", 2.5)
a("power_click", "Chunky heavy industrial toggle switch thunk, single solid mechanical click", 0.7)
a("ui_click", "Short crisp mechanical button click, small relay click, dry", 0.5)
a("ui_hover", "Very soft faint tick, quiet subtle mechanical tap", 0.5)
for i in range(1, 5):
    a(f"typewriter_key_{i}", "Single manual typewriter key strike, a sharp clack with a small metallic ping, dry", 0.5, kind="typewriter_key")
a("radio_squelch", "Old radio squelch burst, short crackle of static as a transmission opens, 1970s military radio", 0.9)
a("radio_static_loop", "Quiet shortwave radio static hiss with faint crackle, steady, seamless loop", 5, True)
a("pursuer_rumble_loop", "Extremely deep sub-bass rumble, distant, something enormous slowly moving through solid rock, ominous, unsettling, slow irregular throbbing, seamless loop", 8, True)
a("hull_groan", "Deep metal stress groan of a submarine hull under immense pressure, long slow creaking, eerie", 4)
a("crew_hurt", "Short dull body impact thump, heavy and muffled, no voice", 0.6)
