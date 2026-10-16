# Needs Stewart

Things only Stewart can do, with exact steps. Empty means nothing is waiting on him.

- **PixelLab key (for the pixel-art style in the art bake-off).** No PixelLab key was found in the
  environment or in `C:\Users\stewa\ClaudeProjects\Noclip\.env`. If you want pixel art compared,
  open that `.env` file in Notepad and add a line `PIXELLAB_API_KEY=<your key>`, save, and tell
  Claude. Without it, the bake-off compares the Blender and painted styles only.
- **Gemini monthly spend cap reached (only if you want more art soon).** The Gemini project that
  makes the painted art hit its monthly spending cap after the M1 art pass (about $15 so far this
  session, all logged in `docs/SPEND.md`). Nothing is blocked for the playtest; a couple of art fixes
  (a better plain-rock tile) wait. To lift it: open https://ai.studio/spend in your browser and raise
  or reset the cap, then tell Claude.
- **Optional cleanup:** a bake-off script briefly wrote to the wrong place and left an empty folder,
  `C:\harness` (its files were moved into the repo). A safety check stopped Claude from deleting it.
  To remove it, paste this into Windows PowerShell:
  ```powershell
  cd "C:\"; Remove-Item -LiteralPath "C:\harness" -Recurse
  ```
- **Optional, any time:** play the M0 test scene by double-clicking
  `C:\Users\stewa\Documents\Claude\Inner Sun\Play Inner Sun.bat` (a window opens; close it to quit).
