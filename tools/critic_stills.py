"""Blind readability check on stills (parity feel rows such as L-DOR-F1).

    python tools/critic_stills.py --stills a.png,b.png --question q.md [--model MODEL] [--out NAME]

Sends the stills and a question to Gemini with no context about the game's code or plans (a fresh
viewer). The question should ask the viewer to describe what it sees (which doorways are shut, which
room is venting) and to rate readability 1 to 5, so the lead can check the answers against what is
true in the still. The reply goes to review/critiques/stills_<NAME>.md and the spend to docs/SPEND.md.
The API key is loaded by critic_gemini.load_key and never printed.
"""
import argparse
import datetime as dt
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import critic_gemini  # noqa: E402
import paths  # noqa: E402

PREAMBLE = ("You are looking at screenshots of a video game you have never seen. You know nothing about "
            "it except what is on screen. Answer only from what you can see; say 'cannot tell' when you "
            "cannot. Do not use em dashes.\n\n")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--stills", required=True, help="comma-separated PNG paths")
    ap.add_argument("--question", required=True, help="a markdown file with the question")
    ap.add_argument("--model", default=critic_gemini.DEFAULT_MODEL)
    ap.add_argument("--out", default=dt.datetime.now().strftime("%Y%m%d-%H%M%S"))
    a = ap.parse_args(argv)
    from google import genai
    from google.genai import types
    key = critic_gemini.load_key()
    if not key:
        print("critic_stills: no Gemini key")
        return 1
    client = genai.Client(api_key=key)
    contents = []
    for p in a.stills.split(","):
        contents.append(types.Part.from_bytes(data=open(p.strip(), "rb").read(), mime_type="image/png"))
    contents.append(PREAMBLE + open(a.question, encoding="utf-8").read())
    cfg = types.GenerateContentConfig(max_output_tokens=8192, temperature=0.4)
    resp = client.models.generate_content(model=a.model, contents=contents, config=cfg)
    if not resp.text:
        print("critic_stills: no reply")
        return 1
    um = resp.usage_metadata
    tin, tout = int(um.prompt_token_count or 0), int(um.candidates_token_count or 0)
    pin, pout = critic_gemini.PRICES["pro" if "pro" in a.model else "flash"]
    cost = tin / 1e6 * pin + tout / 1e6 * pout
    out = os.path.join(paths.ROOT, "review", "critiques", f"stills_{a.out}.md")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(f"# Stills check {a.out} ({a.model})\n\nStills: {a.stills}\n\n{resp.text}\n")
    critic_gemini.log_spend(a.model, os.path.basename(out), tin, tout, cost)
    print(f"critic_stills: reply in {out} ({tin} in / {tout} out tokens, about {cost:.2f} USD)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
