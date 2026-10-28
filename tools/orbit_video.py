"""Record the orbit around a character with Godot's Movie Maker.

    python tools/orbit_video.py                 Oto -> tools/out/orbit.avi and tools/out/orbit.gif
    python tools/orbit_video.py --shadow        in Shadow form (orbit_shadow.*)
    python tools/orbit_video.py --preset goku
    python tools/orbit_video.py --mode anims --no-gif   the animation reel -> tools/out/anims.avi

The camera circles 360 degrees, rises over the head and sweeps below (gallery.gd, --gallery orbit).
The AVI is MJPEG at 30 fps; the GIF (every other frame, half size) needs Pillow.
"""
import argparse
import glob
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preset", default="oto")
    ap.add_argument("--shadow", action="store_true")
    ap.add_argument("--resolution", default="960x720")
    ap.add_argument("--mode", default="orbit", help="gallery mode to record: orbit or anims")
    ap.add_argument("--no-gif", action="store_true")
    a = ap.parse_args()
    os.makedirs(run.OUT, exist_ok=True)
    name = a.mode + ("_shadow" if a.shadow else "") + ("" if a.preset == "oto" else "_" + a.preset)
    gargs = ["--gallery", a.mode, "--preset", a.preset] + (["--shadow"] if a.shadow else [])
    base = ["--path", run.ROOT, "--resolution", a.resolution, "--fixed-fps", "30"]
    tail = ["--", "--scene", "res://scenes/gallery.tscn"] + gargs
    avi = os.path.join(run.OUT, name + ".avi")
    subprocess.run([run.godot()] + base + ["--write-movie", avi] + tail, capture_output=True, timeout=900)
    print(avi if os.path.exists(avi) else "NO AVI")
    if a.no_gif:
        return
    try:
        from PIL import Image
    except ImportError:
        return
    frames_dir = os.path.join(run.OUT, name + "_frames")
    os.makedirs(frames_dir, exist_ok=True)
    for f in glob.glob(os.path.join(frames_dir, "*.png")):
        os.remove(f)
    subprocess.run([run.godot()] + base + ["--write-movie", os.path.join(frames_dir, "f.png")] + tail,
                   capture_output=True, timeout=900)
    pngs = sorted(glob.glob(os.path.join(frames_dir, "f*.png")))[::2]
    if not pngs:
        print("NO FRAMES")
        return
    imgs = []
    for p in pngs:
        im = Image.open(p).convert("RGB")
        imgs.append(im.resize((im.width // 2, im.height // 2), Image.LANCZOS).quantize(colors=192, method=Image.Quantize.MEDIANCUT))
    gif = os.path.join(run.OUT, name + ".gif")
    imgs[0].save(gif, save_all=True, append_images=imgs[1:], duration=66, loop=0, optimize=True)
    print(gif)


if __name__ == "__main__":
    main()
