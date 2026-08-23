#!/usr/bin/env python3
"""Generate an App Store review screenshot of the Wallet quota store UI."""

import os
from PIL import Image, ImageDraw, ImageFont

W, H = 1179, 2556  # iPhone 15 Pro Max @3x
GOLD = (248, 198, 48)
GOLD_DARK = (212, 160, 10)
BG = (250, 250, 252)
CARD = (255, 255, 255)
TEXT = (30, 30, 35)
SUB = (120, 120, 130)

img = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(img)

font_dirs = [
    "/System/Library/Fonts",
    "/System/Library/Fonts/Supplemental",
]
def find_font(name_parts, size):
    for d in font_dirs:
        for f in os.listdir(d):
            low = f.lower()
            if all(p.lower() in low for p in name_parts) and f.endswith((".ttf", ".ttc", ".otf")):
                try:
                    return ImageFont.truetype(os.path.join(d, f), size)
                except Exception:
                    continue
    return ImageFont.load_default()

f_title = find_font(["pingfang", "semibold"], 72)
f_head = find_font(["pingfang", "medium"], 44)
f_card_title = find_font(["pingfang", "semibold"], 48)
f_card_sub = find_font(["pingfang", "regular"], 36)
f_btn = find_font(["pingfang", "semibold"], 42)
f_quota = find_font(["helvetica", "bold"], 60)

# Status bar (simple)
draw.text((60, 60), "9:41", font=find_font(["helvetica"], 40), fill=TEXT)

# Nav title
draw.text((60, 150), "我的额度", font=f_title, fill=TEXT)

# Quota balance card
bx, by, bw, bh = 60, 280, W - 120, 260
draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=36, fill=CARD, outline=(235, 235, 240), width=2)
draw.text((bx + 56, by + 50), "当前可用额度", font=f_head, fill=SUB)
draw.text((bx + 56, by + 120), "3", font=find_font(["helvetica", "bold"], 110), fill=GOLD_DARK)
draw.text((bx + 260, by + 165), "条发布额度", font=f_card_sub, fill=SUB)
draw.text((bx + 56, by + 190), "免费额度已用完，购买后继续发布任务", font=f_card_sub, fill=SUB)

# Section title
draw.text((60, 600), "购买发布额度", font=f_head, fill=TEXT)

# Two package cards
packages = [
    ("pkg_usd_2", "2 Publish Quota", "2 条发布额度", "$0.99"),
    ("pkg_usd_10", "10 Publish Quota", "10 条发布额度", "$4.99"),
]
card_y = 680
card_h = 320
gap = 40
for i, (sku, en, zh, price) in enumerate(packages):
    cy = card_y + i * (card_h + gap)
    cx, cw = 60, W - 120
    draw.rounded_rectangle([cx, cy, cx + cw, cy + card_h], radius=32, fill=CARD, outline=(235, 235, 240), width=2)
    # left: quota count
    draw.text((cx + 56, cy + 90), sku.split("_")[-1] if sku != "pkg_usd_2" else "2", font=f_quota, fill=GOLD_DARK)
    draw.text((cx + 180, cy + 120), "条", font=f_card_sub, fill=SUB)
    # middle: names
    draw.text((cx + 56, cy + 200), en, font=f_card_title, fill=TEXT)
    draw.text((cx + 56, cy + 260), zh, font=f_card_sub, fill=SUB)
    # right: price + buy button
    draw.text((cx + cw - 320, cy + 110), price, font=f_card_title, fill=TEXT)
    draw.rounded_rectangle([cx + cw - 320, cy + 200, cx + cw - 56, cy + 280], radius=28, fill=GOLD)
    draw.text((cx + cw - 230, cy + 215), "购买", font=f_btn, fill=(255, 255, 255))

# Footer note
draw.text((60, card_y + 2 * (card_h + gap) + 40), "额度永久有效 · 不可兑换现金", font=f_card_sub, fill=SUB)

out_dir = "/Users/songheng/CodeBuddy/bountyapp/ios/BountyApp/BountyApp/Resources"
os.makedirs(out_dir, exist_ok=True)
out_path = os.path.join(out_dir, "iap_review_screenshot.png")
img.save(out_path, "PNG")
print(out_path)
