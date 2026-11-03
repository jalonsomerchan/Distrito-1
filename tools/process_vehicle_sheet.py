"""Chroma-key and split an existing five-state vehicle sheet. Never draws art."""
import argparse
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--input", type=Path, required=True)
parser.add_argument("--prefix", required=True)
parser.add_argument("--width", type=int, default=174)
parser.add_argument("--height", type=int, default=444)
args = parser.parse_args()
if not args.prefix.replace("_", "").isalnum():
    parser.error("--prefix must be an alphanumeric filename with optional underscores")
if min(args.width, args.height) < 16:
    parser.error("frame dimensions must be at least 16")

sheet = Image.open(args.input).convert("RGBA")
pixels = []
for r, g, b, a in sheet.getdata():
    strength = min(r, b) - g
    if strength > 100:
        pixels.append((r, g, b, 0))
    elif strength > 35 and r > 150 and b > 120:
        pixels.append((min(r, g + 55), g, min(b, g + 55), round(a * (100 - strength) / 65)))
    else:
        pixels.append((r, g, b, a))
sheet.putdata(pixels)
frames = []
for column in range(5):
    cell = sheet.crop((column * sheet.width // 5, 0, (column + 1) * sheet.width // 5, sheet.height))
    bounds = cell.getbbox()
    if bounds is None or bounds[0] <= 0 or bounds[1] <= 0 or bounds[2] >= cell.width or bounds[3] >= cell.height:
        raise ValueError(f"Cell {column}: empty or touching its edge; regenerate with more margin")
    frames.append((cell.crop(bounds), bounds))
scale = min((args.width - 4) / max(cell.width for cell, _ in frames), (args.height - 4) / max(cell.height for cell, _ in frames))
preview = Image.new("RGBA", (args.width * 5, args.height), (20, 35, 39, 255))
metadata = {"source": str(args.input), "shared_scale": scale, "frame_size": [args.width, args.height], "frames": []}
for index, (cell, bounds) in enumerate(frames):
    cell = cell.resize((round(cell.width * scale), round(cell.height * scale)), Image.Resampling.LANCZOS)
    frame = Image.new("RGBA", (args.width, args.height))
    frame.alpha_composite(cell, ((args.width - cell.width) // 2, (args.height - cell.height) // 2))
    filename = args.prefix + ("" if index == 0 else f"_damage_{index}") + ".png"
    frame.save(ROOT / "assets/sprites" / filename)
    preview.alpha_composite(frame, (index * args.width, 0))
    metadata["frames"].append({"path": "res://assets/sprites/" + filename, "cell": index, "crop": bounds, "edge_touch": False, "alpha": True})
(ROOT / "assets/sprites" / f"{args.prefix}-manifest.json").write_text(json.dumps(metadata, indent=2) + "\n")
preview.save(ROOT / "docs" / f"{args.prefix}-stages.png")
print(json.dumps(metadata, indent=2))
