"""Extract generated city art sheets and record their source metadata."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
manifest = {"sources": {}, "buildings": [], "sidewalks": []}


def remove_magenta(image):
    pixels = []
    for r, g, b, a in image.convert("RGBA").getdata():
        strength = min(r, b) - g
        if strength > 100:
            pixels.append((g, g, g, 0))
        elif strength > 35 and r > 150 and b > 120:
            pixels.append((min(r, g + 55), g, min(b, g + 55), int(a * (100 - strength) / 65)))
        else:
            pixels.append((r, g, b, a))
    result = Image.new("RGBA", image.size)
    result.putdata(pixels)
    return result


for kind, source_name, names, grid, max_size in [
    ("buildings", "building_variants_3x3.png", [f"building_{i:02}" for i in range(6, 15)], 3, 512),
    ("sidewalks", "sidewalk_variants_2x2.png", [f"sidewalk_{i:02}" for i in range(2, 5)], 2, 768),
]:
    sheet = remove_magenta(Image.open(ROOT / "assets/raw" / source_name))
    cell_width, cell_height = sheet.width // grid, sheet.height // grid
    manifest["sources"][kind] = f"assets/raw/{source_name}"
    for index, name in enumerate(names):
        column, row = index % grid, index // grid
        cell = sheet.crop((column * cell_width, row * cell_height,
                           (column + 1) * cell_width, (row + 1) * cell_height))
        bounds = cell.getbbox()
        assert bounds and bounds[0] > 0 and bounds[1] > 0
        assert bounds[2] < cell.width and bounds[3] < cell.height
        sprite = cell.crop(bounds)
        sprite.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
        sprite.save(ROOT / "assets/sprites" / f"{name}.png")
        manifest[kind].append({
            "name": name, "source": f"assets/raw/{source_name}", "cell": index,
            "crop": bounds, "size": sprite.size, "alpha": True, "edge_touch": False,
        })

(ROOT / "assets/sprites/city-variants-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Extracted {len(manifest['buildings'])} rooftops and {len(manifest['sidewalks'])} sidewalk styles")
