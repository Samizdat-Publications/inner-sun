"""Landing page build: copies site/ into site-dist/ and finishes it for Cloudflare Pages.

    python tools/site_build.py            # build site-dist/
    python tools/site_build.py --deploy   # build, then deploy to the Pages project inner-sun

finish-site.mjs (from the showcase kit) writes _headers, _routes.json and functions/media/sizes.json and
fails on any file over 25 MiB. The byte-range function lives in functions/media/ at the repo root.
"""
import argparse
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import paths  # noqa: E402

KIT = r"C:\Users\stewa\Documents\Claude\Github Hub\kit"
SITE = os.path.join(paths.ROOT, "site")
DIST = os.path.join(paths.ROOT, "site-dist")


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--deploy", action="store_true")
    a = ap.parse_args(argv)
    if os.path.exists(DIST):
        shutil.rmtree(DIST)
    shutil.copytree(SITE, DIST)
    node = shutil.which("node") or "node"
    r = subprocess.run([node, os.path.join(KIT, "tools", "finish-site.mjs"), "site-dist"], cwd=paths.ROOT)
    if r.returncode != 0:
        print("site_build: FAIL (finish-site)")
        return 1
    if a.deploy:
        npx = shutil.which("npx") or "npx"
        r = subprocess.run([npx, "--yes", "wrangler@4", "pages", "deploy", "site-dist", "--project-name", "inner-sun",
                            "--branch", "main"], cwd=paths.ROOT)
        if r.returncode != 0:
            print("site_build: FAIL (deploy)")
            return 1
    print("site_build: ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
