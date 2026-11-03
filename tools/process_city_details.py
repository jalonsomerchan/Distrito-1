"""Extract generated city props and resize sand; never draws visual artwork."""
import json
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/environment'
raw = Image.open(ROOT / 'assets/raw/city_details_props.png').convert('RGBA')
pixels = []
for r, g, b, a in raw.getdata():
    strength = min(r, b) - g
    if strength > 100:
        pixels.append((g, g, g, 0))
    elif strength > 30 and r > 130 and b > 110:
        pixels.append((min(r, g + 30), g, min(b, g + 30), round(a * (100 - strength) / 70)))
    else:
        pixels.append((r, g, b, a))
raw.putdata(pixels)
manifest = {'source': 'assets/raw/city_details_props.png', 'tool': 'built-in image_gen', 'props': {}}
for i, name in enumerate(['beach_umbrella', 'beach_lounger', 'bench', 'traffic_signal']):
    col, row = i % 2, i // 2
    image = raw.crop((col * raw.width // 2, row * raw.height // 2, (col + 1) * raw.width // 2, (row + 1) * raw.height // 2))
    bounds = image.getbbox()
    assert bounds and bounds[0] > 0 and bounds[1] > 0 and bounds[2] < image.width and bounds[3] < image.height
    image = image.crop(bounds)
    image.thumbnail((384, 384), Image.Resampling.LANCZOS)
    image.save(OUT / f'{name}.png')
    manifest['props'][name] = {'cell': i, 'crop': bounds, 'size': image.size, 'alpha': True, 'edge_touch': False}
sand = Image.open(ROOT / 'assets/raw/beach_sand.png').convert('RGB')
sand.resize((512, 512), Image.Resampling.LANCZOS).save(OUT / 'sand.png')
(OUT / 'city_details-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest, indent=2))
