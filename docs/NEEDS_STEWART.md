# Needs Stewart

Things only Stewart can do, with exact steps. Empty means nothing is waiting on him.

- **Play the M1a playtest build and write notes (the main thing).** Double-click
  `C:\Users\stewa\Documents\Claude\Inner Sun\Play Inner Sun.bat`, or paste this into Windows PowerShell:
  ```powershell
  cd "C:\Users\stewa\Documents\Claude\Inner Sun"; & "C:\Users\stewa\Documents\Claude\Inner Sun\Play Inner Sun.bat"
  ```
  The controls are in `C:\Users\stewa\Documents\Claude\Inner Sun\README.md` ("How to play"). Play as
  many runs as you like, then write your notes at the top of
  `C:\Users\stewa\Documents\Claude\Inner Sun\docs\STEWART_FEEDBACK.md` under a dated heading: what was
  fun, what was boring or confusing, what you wanted to do and could not. Mention the time of any run
  that went wrong: every run is saved in `%APPDATA%\InnerSun\runs\` and can be replayed exactly.
  Then start the M1b session with the prompt in `HANDOFF.md`.
- **Gemini monthly spend cap reached (only if you want more art or the video critic soon).** The
  Gemini project that makes the painted art hit its monthly spending cap (art and critic spend this
  session: about $15, all in `docs/SPEND.md`). Nothing is blocked for the playtest. To lift it, open
  https://ai.studio/spend in your browser and raise or reset the cap, then tell Claude.
- **PixelLab key (optional).** No PixelLab key was found, so pixel art was never tried in the art
  bake-off. If you want it compared, open `C:\Users\stewa\ClaudeProjects\Noclip\.env` in Notepad, add a
  line `PIXELLAB_API_KEY=<your key>`, save, and tell Claude.
- **Optional cleanup:** a bake-off script briefly wrote to the wrong place and left an empty folder,
  `C:\harness` (its files were moved into the repo). A safety check stopped Claude from deleting it.
  To remove it, paste this into Windows PowerShell:
  ```powershell
  cd "C:\"; Remove-Item -LiteralPath "C:\harness" -Recurse
  ```
