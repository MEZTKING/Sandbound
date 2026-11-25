"""Placeholder Steam store images from the game's beauty shots.

1. Render beauty shots at 1920 x 1080: open tools/beauty_shots.tscn in Godot,
   set the window to 1920 x 1080, press F6 (or run it from the command line
   with --resolution 1920x1080). They land in user://beauty_shots.
2. Run:  python3 make_store_images.py <folder with the beauty shots>
   (needs Pillow: pip install pillow)

It writes steam/store/screenshots/ and steam/store/capsules/ at every size
Steam asks for. The title is plain text: replace these with a designed logo
when you can (Valve checks the logo is readable on the small capsule).
"""
import glob
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(HERE, "store")
FONT = os.path.join(HERE, "..", "fonts", "RubikMonoOne-Regular.ttf")   # the game's title font
TITLE = "SAND ROVER"
TAGLINE = "a tiny courier in a very big desert"


def shot(name):
    return Image.open(os.path.join(SRC, name)).convert("RGB")


def cover(img, w, h, cx=0.5, cy=0.5):
    """Scale to fill w x h and crop (cx, cy = which part to keep)."""
    s = max(w / img.width, h / img.height)
    r = img.resize((int(img.width * s + 1), int(img.height * s + 1)), Image.LANCZOS)
    x, y = int((r.width - w) * cx), int((r.height - h) * cy)
    return r.crop((x, y, x + w, y + h))


def title(img, size, y_frac, sub=None):
    W, H = img.size
    band = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(band).rectangle((0, int(H * y_frac - size * 0.75), W,
                                    int(H * y_frac + size * (1.25 if sub else 0.8))), fill=(0, 0, 0, 110))
    img = Image.alpha_composite(img.convert("RGBA"), band).convert("RGB")
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, size)
    tw = d.textlength(TITLE, font=f)
    x, y = (W - tw) / 2, H * y_frac - size * 0.6
    o = max(2, size // 25)
    for dx, dy in [(-o, 0), (o, 0), (0, -o), (0, o), (o, o)]:
        d.text((x + dx, y + dy), TITLE, font=f, fill=(20, 12, 6))
    d.text((x, y), TITLE, font=f, fill=(255, 214, 140))
    if sub:
        f2 = ImageFont.truetype(os.path.join(HERE, "..", "fonts", "Rubik.ttf"), int(size * 0.3))
        d.text(((W - d.textlength(sub, font=f2)) / 2, y + size * 1.15), sub, font=f2, fill=(255, 255, 255))
    return img


def main():
    os.makedirs(os.path.join(OUT, "screenshots"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "capsules"), exist_ok=True)
    for f in sorted(glob.glob(os.path.join(SRC, "*.png"))):
        shutil.copy(f, os.path.join(OUT, "screenshots", os.path.basename(f)))
    truck, base, drift = shot("2_truck.png"), shot("1_base.png"), shot("5_drift_river.png")
    caps = {   # name: (w, h, source, keep x, keep y, title size, title height, tagline)
        "header_capsule_920x430": (920, 430, truck, 0.55, 0.45, 104, 0.5, TAGLINE),
        "small_capsule_462x174": (462, 174, truck, 0.55, 0.45, 52, 0.5, None),
        "main_capsule_1232x706": (1232, 706, truck, 0.55, 0.45, 140, 0.42, TAGLINE),
        "vertical_capsule_748x896": (748, 896, truck, 0.58, 0.4, 84, 0.16, TAGLINE),
        "library_capsule_600x900": (600, 900, truck, 0.58, 0.4, 68, 0.14, None),
    }
    for name, (w, h, src, cx, cy, size, y, sub) in caps.items():
        title(cover(src, w, h, cx, cy), size, y, sub).save(os.path.join(OUT, "capsules", name + ".png"))
    bg = cover(base, 1438, 810).filter(ImageFilter.GaussianBlur(4))
    ImageEnhance.Brightness(bg).enhance(0.45).save(os.path.join(OUT, "capsules", "page_background_1438x810.png"))
    # Library hero: no text (Steam puts the library logo over it).
    cover(drift, 3840, 1240, 0.5, 0.55).save(os.path.join(OUT, "capsules", "library_hero_3840x1240.png"))
    logo = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    d = ImageDraw.Draw(logo)
    f = ImageFont.truetype(FONT, 170)
    tw = d.textlength(TITLE, font=f)
    for dx, dy in [(-6, 0), (6, 0), (0, -6), (0, 6), (6, 6)]:
        d.text(((1280 - tw) / 2 + dx, 260 + dy), TITLE, font=f, fill=(20, 12, 6, 255))
    d.text(((1280 - tw) / 2, 260), TITLE, font=f, fill=(255, 214, 140, 255))
    logo.save(os.path.join(OUT, "capsules", "library_logo_1280x720.png"))
    print("Store images written to", OUT)


main()
