"""
Seeker App Icon Generator — Golden Snitch (金色飞贼)
Harry Potter inspired: gold sphere with articulated silver wings.
"""
import json, math, os
from PIL import Image, ImageDraw, ImageFilter

# ── Color Palette ──
BG_TOP     = (16, 18, 30, 255)    # deep navy top
BG_BOT     = (38, 40, 62, 255)    # lighter navy bottom
GOLD_BASE  = (212, 175, 55)       # gold base
GOLD_LIGHT = (255, 215, 90)       # gold highlight
GOLD_DARK  = (168, 130, 30)       # gold shadow
SILVER     = (192, 200, 210)      # wing base
SILVER_L   = (230, 238, 245)      # wing highlight
SILVER_D   = (140, 148, 158)      # wing shadow
GLOW_COLOR = (255, 215, 90, 40)   # warm golden glow

# Universal iOS AppIcon set — filename: (pixel size, Contents.json entry)
# iPhone + iPad sizes, all 1x/2x/3x scales.
ICON_SPECS = [
    (1024, "1024x1024.png",    {"idiom":"ios-marketing", "size":"1024x1024", "scale":"1x"}),
    # iPhone
    (60,   "20x20@3x.png",     {"idiom":"iphone", "size":"20x20", "scale":"3x"}),
    (40,   "20x20@2x.png",     {"idiom":"iphone", "size":"20x20", "scale":"2x"}),
    (87,   "29x29@3x.png",     {"idiom":"iphone", "size":"29x29", "scale":"3x"}),
    (58,   "29x29@2x.png",     {"idiom":"iphone", "size":"29x29", "scale":"2x"}),
    (120,  "40x40@3x.png",     {"idiom":"iphone", "size":"40x40", "scale":"3x"}),
    (80,   "40x40@2x.png",     {"idiom":"iphone", "size":"40x40", "scale":"2x"}),
    (180,  "60x60@3x.png",     {"idiom":"iphone", "size":"60x60", "scale":"3x"}),
    (120,  "60x60@2x.png",     {"idiom":"iphone", "size":"60x60", "scale":"2x"}),
    # iPad
    (20,   "20x20@1x.png",     {"idiom":"ipad", "size":"20x20", "scale":"1x"}),
    (40,   "ipad_20x20@2x.png",{"idiom":"ipad", "size":"20x20", "scale":"2x"}),
    (29,   "29x29@1x.png",     {"idiom":"ipad", "size":"29x29", "scale":"1x"}),
    (58,   "ipad_29x29@2x.png",{"idiom":"ipad", "size":"29x29", "scale":"2x"}),
    (40,   "40x40@1x.png",     {"idiom":"ipad", "size":"40x40", "scale":"1x"}),
    (80,   "ipad_40x40@2x.png",{"idiom":"ipad", "size":"40x40", "scale":"2x"}),
    (152,  "76x76@2x.png",     {"idiom":"ipad", "size":"76x76", "scale":"2x"}),
    (167,  "83.5x83.5@2x.png", {"idiom":"ipad", "size":"83.5x83.5", "scale":"2x"}),
]


def make_gradient(size):
    """Dark navy gradient background, fully opaque."""
    img = Image.new("RGBA", (size, size))
    dy = max(1, size // 256)
    for y in range(0, size, dy):
        t = y / size
        r = int(BG_TOP[0] + (BG_BOT[0] - BG_TOP[0]) * t)
        g = int(BG_TOP[1] + (BG_BOT[1] - BG_TOP[1]) * t)
        b = int(BG_TOP[2] + (BG_BOT[2] - BG_TOP[2]) * t)
        yy = min(y + dy, size)
        for yp in range(y, yy):
            for x in range(size):
                img.putpixel((x, yp), (r, g, b, 255))
    return img


def draw_radial_glow(img, cx, cy, body_r, wing_span, size):
    """Soft golden glow behind the snitch."""
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    layers = [
        (body_r * 3.2, 6),
        (body_r * 2.4, 10),
        (body_r * 1.8, 16),
        (body_r * 1.3, 28),
        (body_r * 0.8, 50),
    ]
    for rr, a in layers:
        r = int(rr)
        gd.ellipse([cx - r, cy - r, cx + r, cy + r],
                   fill=(GLOW_COLOR[0], GLOW_COLOR[1], GLOW_COLOR[2], a),
                   outline=None)
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius=max(0.5, size * 0.025))))


def draw_snitch_body(draw, cx, cy, r):
    """Golden metallic sphere with 3D shading and highlight."""
    # Main body — radial gradient simulation with concentric circles
    layers = [
        (r, GOLD_DARK),           # outermost shadow ring
        (int(r * 0.92), GOLD_BASE),
        (int(r * 0.78), GOLD_BASE),
        (int(r * 0.60), GOLD_LIGHT),
        (int(r * 0.38), GOLD_LIGHT),
        (int(r * 0.18), (255, 240, 150)),  # hot spot
    ]
    for rr, color in layers:
        draw.ellipse([cx - rr, cy - rr, cx + rr, cy + rr],
                     fill=color, outline=None)

    # Horizontal equator line — engraving detail
    eq_w = max(1, int(r * 0.04))
    draw.arc([cx - r, cy - r, cx + r, cy + r], 170, 190,
             fill=GOLD_DARK, width=eq_w)
    draw.arc([cx - r, cy - r, cx + r, cy + r], 350, 370,
             fill=GOLD_DARK, width=eq_w)

    # Small specular highlight dot
    hr = max(1, int(r * 0.12))
    hx = cx - int(r * 0.25)
    hy = cy - int(r * 0.28)
    draw.ellipse([hx - hr, hy - hr, hx + hr, hy + hr],
                 fill=(255, 245, 210), outline=None)


def draw_wing(draw, cx, cy, body_r, wing_span, side):
    """
    Draw an articulated wing with feather details.
    side: -1 for left, +1 for right
    """
    dir_x = side  # -1 or 1
    base_x = cx + dir_x * int(body_r * 0.55)
    base_y = cy - int(body_r * 0.15)
    tip_x = cx + dir_x * wing_span
    tip_y = cy - int(body_r * 1.1)
    wing_len = wing_span - int(body_r * 0.55)

    # ── Main wing arc (framework) ──
    # Upper curve (top edge)
    upper_pts = []
    steps = 16
    for i in range(steps + 1):
        t = i / steps
        # Bezier-like cubic easing for natural wing curve
        x = base_x + (tip_x - base_x) * t
        # Arc upward with ease
        arc_y = int(body_r * 1.0 * math.sin(t * math.pi * 0.85))
        y = base_y - (base_y - tip_y) * t - arc_y
        upper_pts.append((x, y))

    # Lower curve (bottom edge) — reverse
    lower_pts = []
    for i in range(steps, -1, -1):
        t = i / steps
        x = base_x + (tip_x - base_x) * t
        arc_y = int(body_r * 0.35 * math.sin(t * math.pi * 0.7))
        y = base_y - (base_y - tip_y) * t + arc_y + int(body_r * 0.12)
        lower_pts.append((x, y))

    wing_poly = upper_pts + lower_pts

    # Wing gradient — silver/lighter toward tip
    mid_color = SILVER
    draw.polygon(wing_poly, fill=mid_color, outline=SILVER_D)

    # ── Wing veins / feather lines (vertical arcs) ──
    lw = max(1, int(body_r * 0.03))
    for j in range(1, 6):
        t = j / 6
        vx = base_x + (tip_x - base_x) * t
        arc_y_top = base_y - (base_y - tip_y) * t - int(body_r * 1.0 * math.sin(t * math.pi * 0.85))
        arc_y_bot = base_y - (base_y - tip_y) * t + int(body_r * 0.35 * math.sin(t * math.pi * 0.7)) + int(body_r * 0.12)
        # Feather arc across wing
        mid_y = (arc_y_top + arc_y_bot) // 2
        feather_h = (arc_y_bot - arc_y_top) // 2
        if feather_h > 1:
            draw.arc([vx - int(feather_h * 0.7), mid_y - feather_h,
                      vx + int(feather_h * 0.7), mid_y + feather_h],
                     0, 180, fill=SILVER_D, width=lw)

    # Wing edge highlight
    draw.line(upper_pts, fill=SILVER_L, width=max(1, lw))
    draw.line(lower_pts, fill=SILVER_D, width=max(1, lw // 2))


def draw_sparkles(draw, cx, cy, body_r, size):
    """Small accent sparkles around the snitch."""
    dots = []
    # Generate positions in a ring around the snitch
    for angle_deg in [20, 55, 110, 160, 210, 260, 310, 350]:
        rad = math.radians(angle_deg)
        dist = body_r * (2.0 + 0.4 * math.sin(3 * rad))  # varying distance
        dx = int(cx + dist * math.cos(rad))
        dy = int(cy + dist * math.sin(rad) * 0.7)
        dots.append((dx, dy))

    for dx, dy in dots:
        sr = max(1, int(body_r * 0.04))
        # Cross sparkle
        draw.ellipse([dx - sr, dy - sr, dx + sr, dy + sr],
                     fill=GOLD_LIGHT, outline=None)
        # Tiny cross rays
        ray = max(0.3, sr * 1.8)
        draw.line([(dx - ray, dy), (dx + ray, dy)],
                  fill=(GOLD_LIGHT[0], GOLD_LIGHT[1], GOLD_LIGHT[2], 60),
                  width=max(1, int(sr * 0.4)))
        draw.line([(dx, dy - ray), (dx, dy + ray)],
                  fill=(GOLD_LIGHT[0], GOLD_LIGHT[1], GOLD_LIGHT[2], 60),
                  width=max(1, int(sr * 0.4)))


def generate(size):
    """Render a single Golden Snitch icon."""
    img = make_gradient(size)
    draw = ImageDraw.Draw(img, "RGBA")
    cx, cy = size // 2, int(size * 0.48)

    # Proportions based on size
    body_r = int(size * 0.115)     # golden sphere radius
    wing_span = int(size * 0.32)   # wing tip distance from center

    # Layer order: background → glow → wings → body → sparkles
    draw_radial_glow(img, cx, cy, body_r, wing_span, size)
    draw_wing(draw, cx, cy, body_r, wing_span, -1)   # left wing
    draw_wing(draw, cx, cy, body_r, wing_span, +1)   # right wing
    draw_snitch_body(draw, cx, cy, body_r)
    draw_sparkles(draw, cx, cy, body_r, size)

    return img.convert("RGB")


def main():
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "BountyApp", "BountyApp", "Assets.xcassets",
                       "AppIcon.appiconset")
    os.makedirs(out, exist_ok=True)

    print("⚡ 生成 Seeker Golden Snitch 图标 ...\n")
    for size, fname, meta in ICON_SPECS:
        path = os.path.join(out, fname)
        icon = generate(size)
        icon.save(path, "PNG")
        print(f"  ✓ {size:>4}×{size:<4}  →  {fname}")

    images = []
    for _, fname, meta in ICON_SPECS:
        entry = {"filename": fname}
        entry.update(meta)
        images.append(entry)

    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    with open(os.path.join(out, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)

    print(f"\n✅ 完成！共 {len(images)} 个尺寸，金色飞贼风格")


if __name__ == "__main__":
    main()
