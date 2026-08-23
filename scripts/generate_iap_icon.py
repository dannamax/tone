#!/usr/bin/env python3
"""Generate a 1024x1024 App Store IAP promotional icon for 1 CNY quota package."""

import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SIZE = 1024
CENTER = SIZE // 2

img = Image.new("RGB", (SIZE, SIZE), "#FFFFFF")
draw = ImageDraw.Draw(img)

# Light blue to white vertical gradient background
for y in range(SIZE):
    ratio = y / SIZE
    r = int(240 - 20 * ratio)
    g = int(248 - 18 * ratio)
    b = int(255 - 10 * ratio)
    draw.line([(0, y), (SIZE, y)], fill=(r, g, b))

# Outer soft shadow circle
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
shadow_draw = ImageDraw.Draw(shadow)
shadow_draw.ellipse(
    [(172, 192), (852, 872)],
    fill=(0, 0, 0, 40)
)
shadow = shadow.filter(ImageFilter.GaussianBlur(radius=30))
img = Image.alpha_composite(img.convert("RGBA"), shadow)

# Golden badge circle
draw = ImageDraw.Draw(img)
badge_box = [(182, 202), (842, 862)]
draw.ellipse(badge_box, fill="#F8C630")

# Inner highlight (slightly smaller, lighter gold)
inner_box = [(210, 230), (814, 834)]
draw.ellipse(inner_box, fill="#FFD54F")

# Try to use a system font with CJK support for the yen symbol
font_paths = [
    "/System/Library/Fonts/Helvetica.ttc",
    "/System/Library/Fonts/PingFang.ttc",
    "/System/Library/Fonts/STHeiti Light.ttc",
    "/System/Library/Fonts/Arial Unicode.ttf",
    "/Library/Fonts/Arial.ttf",
]

symbol_font = None
label_font = None
for path in font_paths:
    if os.path.exists(path):
        try:
            symbol_font = ImageFont.truetype(path, 420)
            label_font = ImageFont.truetype(path, 80)
            break
        except Exception:
            continue

if symbol_font is None:
    symbol_font = ImageFont.load_default()
    label_font = ImageFont.load_default()

# Draw "¥1" in dark gold/brown centered
text = "¥1"
bbox = draw.textbbox((0, 0), text, font=symbol_font)
text_w = bbox[2] - bbox[0]
text_h = bbox[3] - bbox[1]
text_x = (SIZE - text_w) // 2 - bbox[0]
text_y = (SIZE - text_h) // 2 - bbox[1] - 40

# Subtle text shadow
shadow_offset = 6
draw.text((text_x + shadow_offset, text_y + shadow_offset), text, font=symbol_font, fill="#C28E00")
draw.text((text_x, text_y), text, font=symbol_font, fill="#7A5C00")

# Small label below
label = "1 QUOTA"
bbox_label = draw.textbbox((0, 0), label, font=label_font)
label_w = bbox_label[2] - bbox_label[0]
label_x = (SIZE - label_w) // 2
label_y = CENTER + 260
draw.text((label_x, label_y), label, font=label_font, fill="#8A6A00")

# Convert to RGB for PNG
img = img.convert("RGB")

out_dir = "/Users/songheng/CodeBuddy/bountyapp/ios/BountyApp/BountyApp/Resources"
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "iap_icon_pkg_cny_1.png")
img.save(out_path, "PNG")
print(out_path)
