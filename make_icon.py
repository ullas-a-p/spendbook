"""Draws the Spendbook app icon and asset catalog. Run in CI before building."""
import json, math, os
from PIL import Image, ImageDraw, ImageFilter

S = 1024
base = os.path.join("Spendbook", "Assets.xcassets")
icon_dir = os.path.join(base, "AppIcon.appiconset")
accent_dir = os.path.join(base, "AccentColor.colorset")
os.makedirs(icon_dir, exist_ok=True)
os.makedirs(accent_dir, exist_ok=True)

img = Image.new("RGB", (S, S), (6, 14, 11))
glow = Image.new("RGB", (S, S), (0, 0, 0))
ImageDraw.Draw(glow).ellipse((180, 220, 844, 884), fill=(20, 90, 68))
img = Image.blend(img, glow.filter(ImageFilter.GaussianBlur(120)), 0.55)

cx, cy, r = 512, 540, 310
jar = Image.new("RGBA", (S, S), (0, 0, 0, 0))
jd = ImageDraw.Draw(jar)
jd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(15, 42, 33, 255))

def wave(y0, amp, length, phase, color):
    pts = [(0, S)] + [(x, y0 + amp * math.sin(x / length * 2 * math.pi + phase)) for x in range(0, S + 1, 4)] + [(S, S)]
    jd.polygon(pts, fill=color)

wave(cy - 70, 24, 420, 1.2, (31, 110, 85, 255))
wave(cy - 40, 20, 330, 0, (61, 217, 164, 255))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
img.paste(jar, (0, 0), mask)
d = ImageDraw.Draw(img)
d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(61, 217, 164), width=14)
d.rounded_rectangle((cx - r + 60, cy - r - 6, cx + r - 60, cy - r + 16), radius=11, fill=(235, 255, 247))

# Rupee sign drawn from shapes, supersampled
k = 4
glyph = Image.new("L", (512 * k, 512 * k), 0)
gd = ImageDraw.Draw(glyph)
P = lambda x, y: (x * k, y * k)
t = 34 * k
ox, oy = 256 - 115, 256 - 150
gd.rectangle((*P(ox, oy), *P(ox + 230, oy + 34)), fill=255)
gd.rectangle((*P(ox, oy + 80), *P(ox + 230, oy + 114)), fill=255)
gd.arc((*P(ox - 50, oy), *P(ox + 150, oy + 194)), start=-90, end=90, fill=255, width=t)
gd.rectangle((*P(ox, oy + 160), *P(ox + 50, oy + 194)), fill=255)
gd.line((*P(ox + 34, oy + 176), *P(ox + 205, oy + 318)), fill=255, width=int(t * 1.15))
glyph = glyph.resize((512, 512), Image.LANCZOS)
img.paste(Image.new("RGB", (512, 512), (4, 20, 14)), (cx - 256, cy - 256 + 10), glyph)
img.save(os.path.join(icon_dir, "icon-1024.png"))

info = {"author": "xcode", "version": 1}
json.dump({"info": info}, open(os.path.join(base, "Contents.json"), "w"), indent=2)
json.dump({"images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
           "info": info}, open(os.path.join(icon_dir, "Contents.json"), "w"), indent=2)
json.dump({"colors": [{"color": {"color-space": "srgb", "components": {"alpha": "1.000", "red": "0.239", "green": "0.851", "blue": "0.643"}}, "idiom": "universal"}],
           "info": info}, open(os.path.join(accent_dir, "Contents.json"), "w"), indent=2)
print("Icon and asset catalog written")
