# Needs Stewart

Things only Stewart can do, with exact steps. Empty means nothing is waiting on him.

- **Play M1c playtest build 4 (every system has a job in the dig).** Double-click
  `C:\Users\stewa\Documents\Claude\Inner Sun\Play Inner Sun.bat`, or paste this into Windows PowerShell:
  ```powershell
  cd "C:\Users\stewa\Documents\Claude\Inner Sun"; & "C:\Users\stewa\Documents\Claude\Inner Sun\Play Inner Sun.bat"
  ```
  Press H in the game for help (the new keys: A and D turn in steps, S straight down, Shift+A or
  Shift+D cuts sideways, F2 then a click blasts rock, F douses a fire, R on the death report opens
  requisitions). Write notes at the top of
  `C:\Users\stewa\Documents\Claude\Inner Sun\docs\STEWART_FEEDBACK.md`.
- **Hands-on testing by Claude (next session).** Claude asks to control the game window
  (Godot_v4.7.2-stable_win64.exe) to play a run by hand; this session the request was declined, so
  nothing was played with real keys. Approve it next time if you are fine with the game taking over
  the screen for a few minutes.

- **PixelLab key (optional).** No PixelLab key was found, so pixel art was never tried in the art
  bake-off. If you want it compared, open `C:\Users\stewa\ClaudeProjects\Noclip\.env` in Notepad, add a
  line `PIXELLAB_API_KEY=<your key>`, save, and tell Claude.
- **Optional cleanup:** a bake-off script briefly wrote to the wrong place and left an empty folder,
  `C:\harness` (its files were moved into the repo). A safety check stopped Claude from deleting it.
  To remove it, paste this into Windows PowerShell:
  ```powershell
  cd "C:\"; Remove-Item -LiteralPath "C:\harness" -Recurse
  ```
