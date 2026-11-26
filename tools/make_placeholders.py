#!/usr/bin/env python3
"""Generate original placeholder art for Capy Tower Wars.

Shapes are drawn in code (no imported game assets). Replace the PNGs in
assets/sprites later; gameplay code only looks up these filenames.
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
SPRITES.mkdir(parents=True, exist_ok=True)

CAPY = (201, 132, 62, 255)
CAPY_DARK = (138, 85, 40, 255)
SNOUT = (240, 196, 138, 255)
NOSE = (90, 56, 36, 255)
EYE = (32, 26, 22, 255)
EAR = (244, 166, 184, 255)
CHEEK = (240, 140, 150, 180)
CREAM = (255, 248, 238, 255)
WHITE = (255, 255, 255, 255)


def save(img: Image.Image, name: str) -> None:
    path = SPRITES / name
    img.save(path, "PNG")
    print(path.relative_to(ROOT))


def supersample(size: int, draw_fn) -> Image.Image:
    big = size * 2
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw_fn(img, big)
    return img.resize((size, size), Image.Resampling.LANCZOS)


def lerp(a, b, t):
    return int(a + (b - a) * t)


def mix(c1, c2, t):
    return tuple(lerp(c1[i], c2[i], t) for i in range(len(c1)))


def vertical_gradient(size, stops) -> Image.Image:
    w, h = size
    column = Image.new("RGBA", (1, h))
    px = column.load()
    for y in range(h):
        t = y / max(1, h - 1)
        for i in range(len(stops) - 1):
            t0, c0 = stops[i]
            t1, c1 = stops[i + 1]
            if t <= t1 or i == len(stops) - 2:
                span = max(0.0001, t1 - t0)
                px[0, y] = mix(c0, c1, max(0.0, min(1.0, (t - t0) / span)))
                break
    return column.resize((w, h), Image.Resampling.BILINEAR)


def draw_capybara(img: Image.Image, cx: float, cy: float, s: float, accessory: str | None) -> None:
    d = ImageDraw.Draw(img)

    def e(x0, y0, x1, y1, fill):
        d.ellipse((cx + x0 * s, cy + y0 * s, cx + x1 * s, cy + y1 * s), fill=fill)

    # Ears.
    e(-0.62, -0.95, -0.18, -0.42, CAPY_DARK)
    e(0.18, -0.95, 0.62, -0.42, CAPY_DARK)
    e(-0.52, -0.84, -0.26, -0.52, EAR)
    e(0.26, -0.84, 0.52, -0.52, EAR)
    # Head and body blob.
    e(-0.78, -0.55, 0.78, 0.72, CAPY)
    e(-0.78, -0.2, 0.78, 0.78, CAPY)
    # Cheeks.
    e(-0.62, 0.05, -0.28, 0.38, CHEEK)
    e(0.28, 0.05, 0.62, 0.38, CHEEK)
    # Snout.
    e(-0.42, 0.05, 0.42, 0.62, SNOUT)
    e(-0.12, 0.18, 0.12, 0.40, NOSE)
    # Eyes.
    e(-0.40, -0.28, -0.16, -0.02, EYE)
    e(0.16, -0.28, 0.40, -0.02, EYE)
    e(-0.34, -0.24, -0.26, -0.14, WHITE)
    e(0.22, -0.24, 0.30, -0.14, WHITE)
    # Brow dots — keeps the face friendly at small sizes.
    e(-0.08, 0.42, -0.02, 0.50, NOSE)
    e(0.02, 0.42, 0.08, 0.50, NOSE)

    if accessory == "factory":
        e(-0.15, 0.55, 0.55, 1.05, (232, 196, 122, 255))
        d.rectangle(
            (cx - 0.05 * s, cy + 0.62 * s, cx + 0.42 * s, cy + 0.98 * s),
            fill=(214, 168, 86, 255),
        )
        e(0.05, 0.48, 0.28, 0.78, (90, 170, 80, 255))
        e(0.12, 0.38, 0.20, 0.62, (70, 140, 60, 255))
    elif accessory == "artillery":
        # A short seed-lobber: a wooden cup with a sprout, not a copied weapon.
        e(0.15, -0.15, 0.85, 0.35, (122, 78, 42, 255))
        e(0.28, -0.55, 0.72, -0.05, (90, 160, 78, 255))
        e(0.40, -0.78, 0.58, -0.42, (110, 190, 90, 255))


def disc_image(size: int = 256) -> Image.Image:
    def draw(img, n):
        d = ImageDraw.Draw(img)
        m = n * 0.08
        d.ellipse((m, m, n - m, n - m), fill=(255, 255, 255, 255))
        # Soft top gloss so team-colored modulates still look rounded.
        gloss = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        gd = ImageDraw.Draw(gloss)
        gd.ellipse((n * 0.22, n * 0.12, n * 0.78, n * 0.48), fill=(255, 255, 255, 150))
        gloss = gloss.filter(ImageFilter.GaussianBlur(radius=n * 0.03))
        img.alpha_composite(gloss)

    return supersample(size, draw)


def rim_image(size: int = 256) -> Image.Image:
    def draw(img, n):
        d = ImageDraw.Draw(img)
        width = max(8, int(n * 0.07))
        inset = n * 0.06
        d.ellipse((inset, inset, n - inset, n - inset), outline=WHITE, width=width)

    return supersample(size, draw)


def shadow_image(size: int = 256) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((size * 0.12, size * 0.32, size * 0.88, size * 0.72), fill=(0, 0, 0, 140))
    return img.filter(ImageFilter.GaussianBlur(radius=10))


def capybara_image(accessory: str | None, size: int = 256) -> Image.Image:
    def draw(img, n):
        draw_capybara(img, n * 0.5, n * 0.46, n * 0.42, accessory)

    return supersample(size, draw)


def soldier_image(cape: tuple, size: int = 128) -> Image.Image:
    def draw(img, n):
        d = ImageDraw.Draw(img)
        s = n * 0.5
        cx, cy = n * 0.52, n * 0.56
        # Cape behind the body.
        d.polygon(
            [
                (cx - 0.05 * s, cy - 0.05 * s),
                (cx - 0.85 * s, cy + 0.15 * s),
                (cx - 0.15 * s, cy + 0.55 * s),
            ],
            fill=cape,
        )
        d.ellipse((cx - 0.55 * s, cy - 0.22 * s, cx + 0.45 * s, cy + 0.48 * s), fill=CAPY)
        d.ellipse((cx + 0.05 * s, cy - 0.62 * s, cx + 0.78 * s, cy + 0.22 * s), fill=CAPY)
        d.ellipse((cx + 0.42 * s, cy - 0.78 * s, cx + 0.68 * s, cy - 0.42 * s), fill=CAPY_DARK)
        d.ellipse((cx + 0.48 * s, cy - 0.70 * s, cx + 0.62 * s, cy - 0.50 * s), fill=EAR)
        d.ellipse((cx + 0.28 * s, cy - 0.28 * s, cx + 0.78 * s, cy + 0.18 * s), fill=SNOUT)
        d.ellipse((cx + 0.48 * s, cy - 0.12 * s, cx + 0.66 * s, cy + 0.06 * s), fill=NOSE)
        d.ellipse((cx + 0.38 * s, cy - 0.48 * s, cx + 0.52 * s, cy - 0.32 * s), fill=EYE)
        d.ellipse((cx + 0.42 * s, cy - 0.44 * s, cx + 0.47 * s, cy - 0.38 * s), fill=WHITE)
        # Feet.
        d.ellipse((cx - 0.35 * s, cy + 0.28 * s, cx - 0.05 * s, cy + 0.48 * s), fill=CAPY_DARK)
        d.ellipse((cx + 0.05 * s, cy + 0.30 * s, cx + 0.32 * s, cy + 0.50 * s), fill=CAPY_DARK)

    return supersample(size, draw)


def pip_image(size: int = 64) -> Image.Image:
    def draw(img, n):
        d = ImageDraw.Draw(img)
        cx = cy = n / 2
        r = n * 0.42
        pts = []
        for i in range(10):
            ang = -math.pi / 2 + i * math.pi / 5
            rad = r if i % 2 == 0 else r * 0.42
            pts.append((cx + math.cos(ang) * rad, cy + math.sin(ang) * rad))
        d.polygon(pts, fill=(255, 214, 90, 255))

    return supersample(size, draw)


def bramble_image(size: int = 256) -> Image.Image:
    def draw(img, n):
        d = ImageDraw.Draw(img)
        blobs = [
            (0.32, 0.58, 0.22, (92, 130, 62, 255)),
            (0.58, 0.46, 0.26, (70, 110, 48, 255)),
            (0.68, 0.66, 0.20, (110, 150, 70, 255)),
            (0.42, 0.38, 0.16, (80, 120, 52, 255)),
        ]
        for x, y, r, col in blobs:
            d.ellipse(((x - r) * n, (y - r) * n, (x + r) * n, (y + r) * n), fill=col)
        d.arc((n * 0.2, n * 0.3, n * 0.8, n * 0.85), 200, 40, fill=(110, 70, 40, 255), width=max(4, n // 28))

    return supersample(size, draw)


def mud_image(size: int = 256) -> Image.Image:
    def draw(img, n):
        d = ImageDraw.Draw(img)
        d.ellipse((n * 0.08, n * 0.22, n * 0.92, n * 0.82), fill=(122, 86, 52, 255))
        d.ellipse((n * 0.18, n * 0.32, n * 0.78, n * 0.70), fill=(156, 112, 68, 255))
        d.ellipse((n * 0.28, n * 0.38, n * 0.48, n * 0.50), fill=(210, 180, 140, 160))

    return supersample(size, draw)


def icon_image(size: int = 256) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((8, 8, size - 8, size - 8), radius=size * 0.22, fill=(70, 190, 104, 255))
    d.ellipse((size * 0.18, size * 0.06, size * 0.82, size * 0.42), fill=(255, 224, 110, 255))
    cap = capybara_image(None, 256).resize((int(size * 0.72), int(size * 0.72)), Image.Resampling.LANCZOS)
    img.alpha_composite(cap, (int(size * 0.14), int(size * 0.16)))
    # Tiny team disc so the icon reads as a tower game.
    d.ellipse((size * 0.34, size * 0.62, size * 0.66, size * 0.94), fill=(45, 125, 255, 255))
    d.ellipse((size * 0.34, size * 0.62, size * 0.66, size * 0.94), outline=WHITE, width=max(4, size // 40))
    return img


def foreground_icon(size: int = 432) -> Image.Image:
    """Adaptive-icon foreground. Art stays inside the Android safe circle."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    badge = icon_image(256).resize((260, 260), Image.Resampling.LANCZOS)
    img.alpha_composite(badge, ((size - 260) // 2, (size - 260) // 2))
    return img


def background_image() -> Image.Image:
    w, h = 1080, 1920
    img = vertical_gradient(
        (w, h),
        [
            (0.00, (104, 198, 255, 255)),
            (0.22, (186, 232, 255, 255)),
            (0.40, (198, 236, 150, 255)),
            (0.58, (92, 206, 104, 255)),
            (1.00, (46, 158, 78, 255)),
        ],
    )
    d = ImageDraw.Draw(img)
    # Sun, centered so the portrait stays symmetrical.
    d.ellipse((390, 70, 690, 370), fill=(255, 236, 150, 255))
    d.ellipse((450, 130, 630, 310), fill=(255, 248, 210, 255))
    # Mirrored clouds.
    for sign in (-1, 1):
        cx = 540 + sign * 280
        d.ellipse((cx - 90, 150, cx + 70, 250), fill=(255, 255, 255, 230))
        d.ellipse((cx - 40, 120, cx + 110, 230), fill=(255, 255, 255, 230))
        d.ellipse((cx + 40, 155, cx + 150, 245), fill=(255, 255, 255, 230))
    # Soft board behind the towers.
    d.rounded_rectangle((48, 250, 1032, 1720), radius=56, fill=(118, 214, 112, 255))
    d.rounded_rectangle((48, 250, 1032, 1720), radius=56, outline=(255, 255, 255, 230), width=10)
    # Inner clearing, also symmetrical.
    d.ellipse((180, 460, 900, 1500), fill=(150, 224, 126, 255))
    # Corner bushes, mirrored.
    bushes = [(90, 1680), (990, 1680), (70, 430), (1010, 430)]
    for x, y in bushes:
        d.ellipse((x - 70, y - 40, x + 10, y + 50), fill=(48, 140, 70, 255))
        d.ellipse((x - 20, y - 70, x + 70, y + 30), fill=(64, 160, 78, 255))
        d.ellipse((x - 50, y - 20, x + 40, y + 60), fill=(40, 120, 60, 255))
    # Side flowers, kept off the tower columns.
    flower_cols = [36, 1044]
    for x in flower_cols:
        for y in (620, 860, 1100, 1340, 1560):
            d.ellipse((x - 16, y - 16, x + 16, y + 16), fill=(255, 120, 150, 255))
            d.ellipse((x - 6, y - 6, x + 6, y + 6), fill=(255, 230, 120, 255))
            d.rectangle((x - 2, y + 14, x + 2, y + 36), fill=(40, 130, 60, 255))
    return img


def main() -> None:
    save(background_image(), "background.png")
    save(disc_image(), "disc.png")
    save(rim_image(), "rim.png")
    save(shadow_image(), "shadow.png")
    save(capybara_image(None), "capybara.png")
    save(capybara_image("factory"), "capybara_factory.png")
    save(capybara_image("artillery"), "capybara_artillery.png")
    save(bramble_image(), "bramble.png")
    save(mud_image(), "mud.png")
    save(soldier_image((45, 125, 255, 255)), "soldier_player.png")
    save(soldier_image((255, 77, 85, 255)), "soldier_enemy.png")
    save(pip_image(), "pip.png")
    icon = icon_image(256)
    save(icon, "icon.png")
    save(foreground_icon(), "icon_foreground.png")
    # Flat meadow color sits behind the adaptive icon.
    bg = Image.new("RGBA", (432, 432), (70, 190, 104, 255))
    save(bg, "icon_background.png")


if __name__ == "__main__":
    main()
