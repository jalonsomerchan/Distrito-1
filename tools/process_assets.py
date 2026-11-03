"""Deterministic chroma-key/crop of generated artwork (Pillow fallback).

The skill processor cannot import this machine's NumPy/OpenBLAS build.
This only cleans backgrounds and exports existing art; it does not draw sprites.
"""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
metadata = {}


def chroma_key(image):
    image = image.convert("RGBA")
    cleaned = []
    for r, g, b, a in image.getdata():
        # Magenta is absent from the artwork palette. Despill the soft edge.
        strength = min(r, b) - g
        if strength > 100:
            cleaned.append((r, g, b, 0))
        elif strength > 35 and r > 150 and b > 120:
            cleaned.append((min(r, g + 55), g, min(b, g + 55), int(a * (100 - strength) / 65)))
        else:
            cleaned.append((r, g, b, a))
    image.putdata(cleaned)
    return image


for name, max_size in (("car", 256), ("building", 512), ("warehouse", 512), ("sidewalk", 768)):
    image = chroma_key(Image.open(ROOT / "assets/raw" / f"{name}.png"))
    bounds = image.getbbox()
    assert bounds and bounds[0] > 0 and bounds[1] > 0
    assert bounds[2] < image.width and bounds[3] < image.height
    image = image.crop(bounds)
    image.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
    image.save(ROOT / "assets/sprites" / f"{name}.png")
    metadata[name] = {"source": f"assets/raw/{name}.png", "crop": bounds, "size": image.size, "alpha": True, "edge_touch": False}

sheet = chroma_key(Image.open(ROOT / "assets/raw/car_damage_sheet.png"))
cells = []
for row in range(2):
    for col in range(2):
        cell = sheet.crop((col * sheet.width // 2, row * sheet.height // 2,
                           (col + 1) * sheet.width // 2, (row + 1) * sheet.height // 2))
        bounds = cell.getbbox()
        assert bounds and bounds[0] > 0 and bounds[1] > 0
        assert bounds[2] < cell.width and bounds[3] < cell.height
        cells.append((cell.crop(bounds), bounds))
canvas_size = Image.open(ROOT / "assets/sprites/car.png").size
shared_scale = min(canvas_size[0] / max(cell.width for cell, _ in cells),
                   canvas_size[1] / max(cell.height for cell, _ in cells))
preview = Image.new("RGBA", (canvas_size[0] * 5, canvas_size[1]), (20, 35, 39, 255))
preview.alpha_composite(Image.open(ROOT / "assets/sprites/car.png"), (0, 0))
for stage, (cell, bounds) in enumerate(cells, 1):
    cell = cell.resize((round(cell.width * shared_scale), round(cell.height * shared_scale)), Image.Resampling.LANCZOS)
    frame = Image.new("RGBA", canvas_size)
    frame.alpha_composite(cell, ((canvas_size[0] - cell.width) // 2, (canvas_size[1] - cell.height) // 2))
    frame.save(ROOT / f"assets/sprites/car_damage_{stage}.png")
    preview.alpha_composite(frame, (stage * canvas_size[0], 0))
    metadata[f"car_damage_{stage}"] = {"source": "assets/raw/car_damage_sheet.png", "cell": stage - 1,
        "crop": bounds, "size": canvas_size, "shared_scale": shared_scale, "alpha": True, "edge_touch": False}
preview.save(ROOT / "docs/car-damage-stages.png")
(ROOT / "assets/sprites/manifest.json").write_text(json.dumps(metadata, indent=2))
print(json.dumps(metadata, indent=2))
