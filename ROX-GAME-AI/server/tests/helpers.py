import glob
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFont


def font(size):
    cands = [r"C:\Windows\Fonts\arial.ttf", r"C:\Windows\Fonts\segoeui.ttf"] + glob.glob("/usr/share/fonts/**/DejaVuSans.ttf", recursive=True) + glob.glob("/usr/share/fonts/**/*.ttf", recursive=True)
    for c in cands:
        if os.path.exists(c):
            return ImageFont.truetype(c, size)
    return ImageFont.load_default()


def game_frame(cx=640, w=1280, h=720):
    """Synthetic TEST game frame: mission banner, dialogue box, moving skin-tone shape."""
    img = Image.new("RGB", (w, h), (24, 34, 30))
    d = ImageDraw.Draw(img)
    d.ellipse([cx - 90, 150, cx + 90, 420], fill=(224, 172, 140))
    d.text((40, 40), "Mission: Reach the old lighthouse", fill=(255, 255, 255), font=font(34))
    d.rectangle([120, h - 150, w - 120, h - 40], fill=(0, 0, 0))
    d.text((150, h - 115), "Elena: We must find the ancient key before nightfall.", fill=(255, 255, 255), font=font(36))
    return np.asarray(img).copy()
