"""Build BioTracer launcher icons from assets/branding/05-simbolo-azul.png."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "branding" / "05-simbolo-azul.png"
WHITE = (255, 255, 255, 255)
# iOS-like squircle; baked into regular icons so the tab/tile looks rounded.
CORNER = 0.22


def crop_mark(im: Image.Image) -> Image.Image:
    bbox = im.split()[-1].getbbox()
    if bbox is None:
        raise SystemExit("05-simbolo-azul.png has no visible pixels")
    return im.crop(bbox)


def fit_mark(mark: Image.Image, canvas: int, occupancy: float) -> Image.Image:
    target = max(1, int(canvas * occupancy))
    w, h = mark.size
    scale = target / max(w, h)
    size = (max(1, round(w * scale)), max(1, round(h * scale)))
    return mark.resize(size, Image.Resampling.LANCZOS)


def compose(
    canvas: int,
    occupancy: float,
    *,
    background: tuple[int, int, int, int] | None,
    rounded: bool = False,
) -> Image.Image:
    supersample = 4 if canvas < 256 else 2
    work = canvas * supersample
    layer = Image.new("RGBA", (work, work), (0, 0, 0, 0))
    if background is not None:
        plate = Image.new("RGBA", (work, work), (0, 0, 0, 0))
        draw = ImageDraw.Draw(plate)
        if rounded:
            radius = max(1, round(work * CORNER))
            draw.rounded_rectangle((0, 0, work - 1, work - 1), radius=radius, fill=background)
        else:
            draw.rectangle((0, 0, work - 1, work - 1), fill=background)
        layer.alpha_composite(plate)
    mark = fit_mark(MARK, work, occupancy)
    x = (work - mark.width) // 2
    y = (work - mark.height) // 2
    layer.alpha_composite(mark, (x, y))
    if supersample == 1:
        return layer
    return layer.resize((canvas, canvas), Image.Resampling.LANCZOS)


def save(im: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG")
    print(f"wrote {path.relative_to(ROOT)} {im.size}")


MARK = crop_mark(Image.open(SRC).convert("RGBA"))

# Master assets for future regeneration.
save(
    compose(1024, 0.62, background=WHITE, rounded=True),
    ROOT / "assets" / "branding" / "icon" / "app_icon.png",
)
save(
    compose(1024, 0.62, background=None),
    ROOT / "assets" / "branding" / "icon" / "app_icon_foreground.png",
)

# Web / PWA — regular icons bake the rounded white tile (like fly.dev in the tab).
web = ROOT / "web"
save(compose(64, 0.62, background=WHITE, rounded=True), web / "favicon.png")
save(compose(180, 0.62, background=WHITE, rounded=True), web / "apple-touch-icon.png")
save(compose(192, 0.62, background=WHITE, rounded=True), web / "icons" / "Icon-192.png")
save(compose(512, 0.62, background=WHITE, rounded=True), web / "icons" / "Icon-512.png")
# Maskable stays full-bleed; the OS clips to the squircle.
save(compose(192, 0.58, background=WHITE), web / "icons" / "Icon-maskable-192.png")
save(compose(512, 0.58, background=WHITE), web / "icons" / "Icon-maskable-512.png")

# Android legacy launcher — rounded white tile.
mipmap = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
res = ROOT / "android" / "app" / "src" / "main" / "res"
for density, size in mipmap.items():
    save(
        compose(size, 0.62, background=WHITE, rounded=True),
        res / f"mipmap-{density}" / "ic_launcher.png",
    )

# Android adaptive foreground (108dp * density)
adaptive = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}
for density, size in adaptive.items():
    save(
        compose(size, 0.42, background=None),
        res / f"drawable-{density}" / "ic_launcher_foreground.png",
    )
