# Needs Stewart

Things only Stewart can do, with exact steps. Empty means nothing is waiting on him.

- **Play M1b playtest build 3 (the digging version).** Double-click
  `C:\Users\stewa\Documents\Claude\Inner Sun\Play Inner Sun.bat`, or paste this into Windows PowerShell:
  ```powershell
  cd "C:\Users\stewa\Documents\Claude\Inner Sun"; & "C:\Users\stewa\Documents\Claude\Inner Sun\Play Inner Sun.bat"
  ```
  Press H in the game for help. Write notes at the top of
  `C:\Users\stewa\Documents\Claude\Inner Sun\docs\STEWART_FEEDBACK.md`.

- **PixelLab key (optional).** No PixelLab key was found, so pixel art was never tried in the art
  bake-off. If you want it compared, open `C:\Users\stewa\ClaudeProjects\Noclip\.env` in Notepad, add a
  line `PIXELLAB_API_KEY=<your key>`, save, and tell Claude.
- **Optional cleanup:** a bake-off script briefly wrote to the wrong place and left an empty folder,
  `C:\harness` (its files were moved into the repo). A safety check stopped Claude from deleting it.
  To remove it, paste this into Windows PowerShell:
  ```powershell
  cd "C:\"; Remove-Item -LiteralPath "C:\harness" -Recurse
  ```
