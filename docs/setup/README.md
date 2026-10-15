# Setup files waiting to be installed

`critic/` holds the blind player-critic's two files. The planning session could not write them
into `.claude/` because it inherited a deny rule from Cut & Fill for exactly those paths. The first
build session installs them (HANDOFF.md, "Step 0 details"):

| Staged file | Installs to |
|---|---|
| `critic/critic_guard.mjs` | `.claude/hooks/critic_guard.mjs` |
| `critic/player-critic.md` | `.claude/agents/player-critic.md` |

Then run `python tools/test_guard.py` (must print `guard: ok`), do the live test, and add deny rules
for both installed files to `.claude/settings.json`. After that, these staged copies are only a
reference; the installed files are the ones that count.
