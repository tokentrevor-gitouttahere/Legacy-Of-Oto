"""Export the web build and publish it to GitHub Pages (the gh-pages branch).

    python tools/publish_web.py              export, then push export/web to gh-pages
    python tools/publish_web.py --no-export  push the existing export/web as it is
    python tools/publish_web.py --dry-run    export and stage, but do not push

Needs the Godot 4.7.2 web export templates in %APPDATA%/Godot/export_templates/4.7.2.stable
and the "Web" preset in export_presets.cfg (no threads, so Pages needs no special headers).
The site is https://tokentrevor-gitouttahere.github.io/Legacy-Of-Oto/ (Pages source: gh-pages, /).
The gh-pages branch holds only the latest build; each publish replaces it.
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WEB = os.path.join(ROOT, "export", "web")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import run  # noqa: E402  (finds the Godot binary)


def git(*args, cwd=ROOT):
    return subprocess.run(["git"] + list(args), cwd=cwd, check=True, capture_output=True, text=True).stdout.strip()


def export():
    os.makedirs(WEB, exist_ok=True)
    p = subprocess.run([run.godot(), "--headless", "--path", ROOT, "--export-release", "Web",
                        os.path.join(WEB, "index.html")], capture_output=True, text=True, errors="replace")
    errors = [l for l in (p.stdout + p.stderr).splitlines() if "ERROR" in l or "SCRIPT ERROR" in l]
    if p.returncode != 0 or not os.path.exists(os.path.join(WEB, "index.wasm")):
        print("\n".join(errors) or p.stdout[-2000:])
        sys.exit("export failed")
    print("exported to", os.path.relpath(WEB, ROOT))


def publish(dry_run):
    remote = git("remote", "get-url", "origin")
    name, email = git("config", "user.name"), git("config", "user.email")
    rev = git("rev-parse", "--short", "HEAD")
    tmp = tempfile.mkdtemp(prefix="oto_pages_")
    try:
        for f in os.listdir(WEB):
            shutil.copy2(os.path.join(WEB, f), tmp)
        open(os.path.join(tmp, ".nojekyll"), "w").close()
        git("init", "-q", "-b", "gh-pages", cwd=tmp)
        git("config", "user.name", name, cwd=tmp)
        git("config", "user.email", email, cwd=tmp)
        git("add", "-A", cwd=tmp)
        git("commit", "-q", "-m", "Web build of %s\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" % rev, cwd=tmp)
        if dry_run:
            print("dry run: staged in", tmp)
            return
        git("push", "-f", remote, "gh-pages", cwd=tmp)
        print("pushed gh-pages (build of %s)" % rev)
    finally:
        if not dry_run:
            shutil.rmtree(tmp, ignore_errors=True)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--no-export", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    if not a.no_export:
        export()
    publish(a.dry_run)


if __name__ == "__main__":
    main()
