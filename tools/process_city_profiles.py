"""Extract generated city rooftops and landmark sprites from 2x2 sheets."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SHEETS = {
    "barcelona": ("barcelona_props.png", {0: "sagrada_familia", 2: "casa_batllo"}),
    "paris": ("paris_props.png", {0: "eiffel_tower", 2: "louvre"}),
    "miami": ("miami_props.png", {0: "freedom_tower", 1: "art_deco_hotel"}),
    "los_angeles": ("los_angeles_props.png", {0: "griffith_observatory", 3: "city_hall"}),
}


def remove_magenta(image: Image.Image) -> Image.Image:
    result = Image.new("RGBA", image.size)
    pixels = []
    for r, g, b, a in image.convert("RGBA").getdata():
        strength = min(r, b) - g
        if strength > 100:
            pixels.append((g, g, g, 0))
        elif strength > 35 and r > 150 and b > 120:
            pixels.append((min(r, g + 55), g, min(b, g + 55), int(a * (100 - strength) / 65)))
        else:
            pixels.append((r, g, b, a))
    result.putdata(pixels)
    return result


manifest = {"tool": "built-in image_gen", "cities": {}}
for city, (filename, landmarks) in SHEETS.items():
    source = ROOT / "assets/raw" / filename
    sheet = remove_magenta(Image.open(source))
    city_dir = ROOT / "assets/environment/cities" / city
    city_dir.mkdir(parents=True, exist_ok=True)
    cell_w, cell_h = sheet.width // 2, sheet.height // 2
    items = []
    for i in range(4):
        col, row = i % 2, i // 2
        cell = sheet.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
        bounds = cell.getbbox()
        assert bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < cell.width and bounds[3] < cell.height
        sprite = cell.crop(bounds)
        sprite.thumbnail((640, 640), Image.Resampling.LANCZOS)
        is_landmark = i in landmarks
        name = landmarks[i] if is_landmark else f"roof_{i}"
        output = city_dir / f"{name}.png"
        sprite.save(output)
        items.append({"name": name, "cell": i, "crop": bounds, "size": sprite.size,
                      "alpha": True, "edge_touch": False, "landmark": is_landmark,
                      "path": str(output.relative_to(ROOT))})
    manifest["cities"][city] = {"source": str(source.relative_to(ROOT)), "items": items}

(ROOT / "assets/environment/city-profiles-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print("Extracted 16 city sprites")
