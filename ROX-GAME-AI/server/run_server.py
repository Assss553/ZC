import sys


def selftest(path="rox-selftest.txt"):
    """Headless check of the packaged exe: loads every engine and runs OCR + Safe Vision on a test frame."""
    import numpy as np
    from PIL import Image, ImageDraw, ImageFont

    from rox_server.ocr import OCR
    from rox_server.safevision import detect
    from rox_server.translate import Translator
    lines = []
    img = Image.new("RGB", (1280, 720), (24, 34, 30))
    d = ImageDraw.Draw(img)
    try:
        f = ImageFont.truetype(r"C:\Windows\Fonts\arial.ttf", 36)
    except Exception:
        f = ImageFont.load_default()
    d.ellipse([550, 150, 730, 420], fill=(224, 172, 140))
    d.text((150, 600), "Elena: We must find the ancient key before nightfall.", fill=(255, 255, 255), font=f)
    rgb = np.asarray(img).copy()
    blocks = OCR().read(rgb)
    lines.append("OCR: " + " | ".join(b["text"] for b in blocks))
    lines.append(f"SafeVision regions: {len(detect(rgb))}")
    tr = Translator("ar")
    lines.append(f"Translator device: {tr.device}")
    ok = any("ancient key" in b["text"].lower() for b in blocks)
    lines.append("RESULT: " + ("OK" if ok else "FAIL"))
    open(path, "w", encoding="utf-8").write("\n".join(lines))
    return 0 if ok else 1


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(selftest())
    from rox_server.app import main
    main()
