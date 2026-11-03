"""Build authored city map variants from the existing road/block layout."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
base = json.loads((ROOT / "data/city_layout.json").read_text())
details = json.loads((ROOT / "data/city_details.json").read_text())

profiles = {
    "barcelona": {
        "coastal": True,
        "name": "BARCELONA", "tagline": "EIXAMPLE · COSTA MEDITERRÁNEA",
        "landmark": "SAGRADA FAMÍLIA · CASA BATLLÓ", "summary": "Manzanas achaflanadas y tejados modernistas junto al mar.",
        "water": "#287d89", "urban": "#31363b", "ground": "#65724e", "parks": "#4c8456",
        "buildings": ["assets/environment/cities/barcelona/roof_1.png", "assets/environment/cities/barcelona/roof_3.png"],
        "landmarks": [
            {"block": [7, 8], "sprite": "assets/environment/cities/barcelona/sagrada_familia.png", "name": "SAGRADA FAMÍLIA"},
            {"block": [9, 6], "sprite": "assets/environment/cities/barcelona/casa_batllo.png", "name": "CASA BATLLÓ"}],
        "roundabouts": [[7400, 3510, 65], [14135, 10230, 65]], "districts": ["GÒTIC", "EIXAMPLE", "GRÀCIA", "MONTJUÏC"],
        "beaches": ["BARCELONETA", "CALA DEL PINAR", "PLAYA BRAVA"],
    },
    "paris": {
        "coastal": False,
        "name": "PARÍS", "tagline": "RIVE GAUCHE · SEINE",
        "landmark": "TORRE EIFFEL · LOUVRE", "summary": "La Seine divide la ciudad; tres puentes conectan sus barrios.",
        "water": "#397c91", "urban": "#353941", "ground": "#70745f", "parks": "#5d8056",
        "buildings": ["assets/environment/cities/paris/roof_1.png", "assets/environment/cities/paris/roof_3.png"],
        "landmarks": [
            {"block": [0, 8], "sprite": "assets/environment/cities/paris/eiffel_tower.png", "name": "TOUR EIFFEL"},
            {"block": [9, 2], "sprite": "assets/environment/cities/paris/louvre.png", "name": "MUSÉE DU LOUVRE"}],
        "roundabouts": [[7400, 3510, 100]], "districts": ["LE MARAIS", "ÎLE DE LA CITÉ", "RIVE GAUCHE", "MONTMARTRE"],
        "beaches": ["BORDS DE SEINE", "QUAIS DE PARIS", "PROMENADE DU SUD"],
    },
    "miami": {
        "coastal": True,
        "name": "MIAMI", "tagline": "SOUTH BEACH · INTRACOASTAL",
        "landmark": "FREEDOM TOWER · SOUTH BEACH", "summary": "Canales, hoteles Art Déco y avenidas de palmeras.",
        "water": "#268c9a", "urban": "#344047", "ground": "#8a7858", "parks": "#5d8956",
        "buildings": ["assets/environment/cities/miami/roof_2.png", "assets/environment/cities/miami/roof_3.png"],
        "landmarks": [
            {"block": [5, 4], "sprite": "assets/environment/cities/miami/freedom_tower.png", "name": "FREEDOM TOWER"},
            {"block": [7, 8], "sprite": "assets/environment/cities/miami/art_deco_hotel.png", "name": "SOUTH BEACH ART DÉCO"}],
        "roundabouts": [], "districts": ["DOWNTOWN", "SOUTH BEACH", "ART DÉCO", "LITTLE HAVANA"],
        "beaches": ["SOUTH BEACH", "NORTH BEACH", "KEY BISCAYNE"],
    },
    "los_angeles": {
        "coastal": True,
        "name": "LOS ÁNGELES", "tagline": "DOWNTOWN · HOLLYWOOD HILLS",
        "landmark": "GRIFFITH OBSERVATORY · CITY HALL", "summary": "Supermanzanas, palmeras y colinas sobre el downtown.",
        "water": "#327b88", "urban": "#3a3937", "ground": "#7e704d", "parks": "#668052",
        "buildings": ["assets/environment/cities/los_angeles/roof_1.png", "assets/environment/cities/los_angeles/roof_2.png"],
        "landmarks": [
            {"block": [2, 9], "sprite": "assets/environment/cities/los_angeles/griffith_observatory.png", "name": "GRIFFITH OBSERVATORY"},
            {"block": [9, 2], "sprite": "assets/environment/cities/los_angeles/city_hall.png", "name": "LOS ANGELES CITY HALL"}],
        "roundabouts": [[7400, 8710, 90]], "districts": ["DOWNTOWN", "HOLLYWOOD", "ECHO PARK", "MIRACLE MILE"],
        "beaches": ["SANTA MONICA", "VENICE BEACH", "MALIBU"],
    },
}

for city, profile in profiles.items():
    layout = copy.deepcopy(base)
    # Give each city its own cadence of plazas, pavements and chamfered blocks.
    for ci, column in enumerate(layout["columns"]):
        for bi, block in enumerate(column["blocks"]):
            if (ci, bi) in [tuple(x["block"]) for x in profile["landmarks"]]:
                block["kind"] = "park"
            elif city == "barcelona" and block["kind"] == "buildings" and column["width"] >= 620 and block["height"] >= 600 and (ci * 3 + bi * 5) % 9 in (1, 4):
                block["angle"] = 18 if (ci + bi) % 2 == 0 else -18
            elif city == "los_angeles" and block["kind"] == "buildings" and column["width"] >= 900 and block["height"] >= 700 and (ci + bi) % 5 == 2:
                block["kind"] = "vacant" if (ci + bi) % 2 else "park"
            elif city == "miami" and block["kind"] == "buildings" and (ci * 7 + bi * 3) % 11 == 4:
                block["kind"] = "park"
            block["sidewalk"] = (ci * 2 + bi + list(profiles).index(city)) % 4
    if city == "barcelona":
        layout["rivers"] = []
        layout["bridges"] = []
        layout["districts"] = [
            {"name": profile["districts"][0], "rect": [-400, -400, 4800, 4800]},
            {"name": profile["districts"][1], "rect": [4400, -400, 6200, 13200]},
            {"name": profile["districts"][2], "rect": [7100, 4200, 7300, 4200]},
            {"name": profile["districts"][3], "rect": [-400, 8400, 6600, 4400]},
        ]
    elif city == "paris":
        layout["rivers"] = [{"name": "LA SEINE", "rect": [-400, 7500, 14800, 900]}]
        layout["bridges"] = [
            {"name": "PONT NEUF", "rect": [605, 7100, 320, 1700], "axis": "vertical"},
            {"name": "PONT DES ARTS", "rect": [7240, 7100, 320, 1700], "axis": "vertical"},
            {"name": "PONT ALEXANDRE III", "rect": [13975, 7100, 320, 1700], "axis": "vertical"},
        ]
        layout["districts"] = [{"name": name, "rect": rect} for name, rect in zip(profile["districts"], [[-400,-400,4800,4800],[4400,4400,2600,2400],[7100,4400,7300,3200],[7100,8400,7300,4400]])]
    elif city == "miami":
        layout["rivers"] = [
            {"name": "BISCAYNE BAY", "rect": [6200, -400, 900, 13200]},
            {"name": "MIAMI RIVER", "rect": [-400, 7800, 6600, 600]},
        ]
        layout["bridges"] = [
            {"name": "MACARTHUR CAUSEWAY", "rect": [5800, 1900, 1700, 320], "axis": "horizontal"},
            {"name": "DOWNTOWN BRIDGE", "rect": [5800, 6000, 1700, 320], "axis": "horizontal"},
            {"name": "RICKENBACKER CAUSEWAY", "rect": [5800, 10600, 1700, 320], "axis": "horizontal"},
            {"name": "VENETIAN CAUSEWAY", "rect": [625, 7540, 280, 1120], "axis": "vertical"},
            {"name": "BRICKELL BRIDGE", "rect": [5660, 7540, 280, 1120], "axis": "vertical"},
        ]
        layout["districts"] = [
            {"name": "DOWNTOWN", "rect": [-400,-400,4800,4800]},
            {"name": "LITTLE HAVANA", "rect": [-400,4400,4800,4000]},
            {"name": "BRICKELL", "rect": [4400,4400,1800,4000]},
            {"name": "SOUTH BEACH", "rect": [7100,-400,7300,4600]},
            {"name": "ART DÉCO DISTRICT", "rect": [7100,4200,7300,4200]},
            {"name": "COCONUT GROVE", "rect": [7100,8400,7300,4400]},
        ]
    else:
        layout["rivers"] = []
        layout["bridges"] = []
        # Wide arterial gaps break up the regular grid into LA-style superblocks.
        for i, column in enumerate(layout["columns"]):
            if i % 3 == 1:
                column["width"] = max(460, column["width"] - 120)
        layout["districts"] = [
            {"name": "DOWNTOWN", "rect": [-400,-400,4800,4800]},
            {"name": "HOLLYWOOD", "rect": [4400,-400,6200,4800]},
            {"name": "ECHO PARK", "rect": [-400,4400,6600,4000]},
            {"name": "MIRACLE MILE", "rect": [7100,4400,7300,4000]},
            {"name": "HOLLYWOOD HILLS", "rect": [-400,8400,14800,4400]},
        ]
    (ROOT / f"data/city_layout_{city}.json").write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n")

    detail = copy.deepcopy(details)
    detail["beaches"] = []
    detail["roundabouts"] = [{"name": f"ROTONDA {n}", "center": [x,y], "radius": r} for n,(x,y,r) in enumerate(profile["roundabouts"],1)]
    (ROOT / f"data/city_details_{city}.json").write_text(json.dumps(detail, ensure_ascii=False, indent=2) + "\n")

(ROOT / "data/cities.json").write_text(json.dumps({"version": 1, "cities": profiles}, ensure_ascii=False, indent=2) + "\n")
print("Generated four distinct city layouts and profiles")
