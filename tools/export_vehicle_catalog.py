"""Export a readable table from the same catalog consumed by Godot."""
import json
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def merge(base, overrides):
    result = deepcopy(base)
    for key, value in overrides.items():
        result[key] = merge(result[key], value) if isinstance(value, dict) and isinstance(result.get(key), dict) else deepcopy(value)
    return result


catalog = json.loads((ROOT / "data/vehicles.json").read_text())
lines = ["# Catálogo de coches", "", "Generado desde `data/vehicles.json`. Cambia ese JSON y ejecuta `python3 tools/export_vehicle_catalog.py` para actualizar esta tabla.", "", "| ID estable | Nombre | Máxima (km/h HUD) | Aceleración (u/s²) | Agarre (s⁻¹) | Vida | Tamaño | Colisión | Bots | Peso tráfico |", "| --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | ---: |"]
for entry in catalog["vehicles"]:
    model = merge(catalog["defaults"], entry)
    lines.append(f'| `{model["id"]}` | {model["name"]} | {model["max_speed"] * catalog["units"]["speed_to_kmh"]:.1f} | {model["acceleration"]:g} | {model["grip"]:g} | {model["max_health"]:g} | {model["draw_size"][0]} × {model["draw_size"][1]} | {model["collision_size"][0]} × {model["collision_size"][1]} | {"Sí" if model["bots_allowed"] else "No"} | {model["ai"]["spawn_weight"]:g} |')
guide = """

## Estructura y campos

`defaults` contiene los valores comunes. Cada entrada de `vehicles` los sobrescribe; los objetos anidados, como `ai`, también se combinan. El orden de la lista define el orden del selector. El ID identifica el modelo en los guardados y no depende de ese orden.

| Grupo | Campos | Uso real |
| --- | --- | --- |
| Identidad | `id`, `name`, `category`, `description` | ID para guardado, nombre para el selector y metadatos del modelo. |
| Permisos | `player_allowed`, `bots_allowed` | Filtran el selector y los modelos generados en el tráfico. |
| Motor | `max_speed`, `acceleration`, `reverse_speed`, `reverse_acceleration` | Velocidad y aceleración hacia delante y en marcha atrás. |
| Frenos | `braking`, `coast_deceleration`, `handbrake_deceleration` | Frenado, desaceleración al soltar gas y freno de mano. |
| Dirección | `steering_rate`, `handbrake_steering_rate`, `steering_response_speed` | Giro normal, giro al derrapar y velocidad necesaria para alcanzar toda la respuesta. |
| Agarre | `grip`, `drift_grip` | Corrección de la velocidad lateral; un valor alto reduce el deslizamiento. La IA también lo usa para suavizar la orientación. |
| Superficie | `sidewalk_max_speed` | Límite al circular por una acera. |
| Resistencia | `max_health`, `damage_multiplier` | Vida absoluta y multiplicador del daño recibido; menos de 1 resiste más. |
| Apariencia | `sprites` | Cinco rutas: nuevo, leve, medio, grave y destrozado. Los estados dependen del porcentaje de vida. |
| Geometría | `draw_size`, `collision_size` | Tamaño del sprite y de la colisión; también adaptan los sensores de IA. |
| Tráfico | `ai.cruise_min`, `ai.cruise_max`, `ai.corner_speed` | Velocidad de circulación y límite en curvas, sin superar la máxima del modelo. |
| Conducción IA | `ai.acceleration`, `ai.braking` | Aceleración y frenado de circulación, limitados por la capacidad del modelo. |
| Tamaño en IA | `ai.follow_distance`, `ai.corner_lookahead`, `ai.lane_offset`, `ai.turn_radius` | Distancia de seguimiento, anticipación de curvas, separación al bordillo y radio de giro. |
| Frecuencia IA | `ai.spawn_weight` | Peso relativo de aparición; `bots_allowed: false` siempre excluye al modelo. |

Las velocidades están en unidades/segundo y las aceleraciones y frenadas en unidades/segundo². Los giros están en radianes/segundo y el agarre es una tasa de respuesta. `units` define las conversiones del HUD; `damage` centraliza la fórmula de choque, la protección entre impactos, los nombres y los umbrales de los cinco estados.

El cargador `scripts/vehicle_catalog.gd` valida IDs únicos, tipos, valores positivos y finitos, permisos, parámetros de IA y recursos gráficos. Resuelve la herencia, mantiene una caché y devuelve copias para evitar modificaciones accidentales de la configuración compartida.

## Añadir un modelo

La guía completa está en `docs/como-anadir-un-vehiculo.md`, con generación de sprites, procesado y ejemplo JSON para un vehículo de otro tamaño.

1. Añade una entrada con un `id` nuevo, nombre, descripción, categoría y las cinco rutas de sprite.
2. Sobrescribe las estadísticas que cambien respecto a `defaults`.
3. Configura `player_allowed`, `bots_allowed` y el peso de tráfico. Para excluirlo de los bots basta con `bots_allowed: false`.
4. Ejecuta `godot --headless --path . --script tests/catalog.gd` y vuelve a exportar el juego.

El catálogo se carga al arrancar: reinicia la ejecución tras editarlo. Los guardados nuevos incluyen `vehicle_id` y vida absoluta; los antiguos sin ID se cargan con el modelo por defecto. El HUD muestra el porcentaje respecto a la vida total de cada coche. El clásico está inicialmente reservado al jugador para demostrar el filtro de bots; puedes habilitarlo en el JSON y darle un peso positivo.
"""
(ROOT / "docs/vehicle-catalog.md").write_text("\n".join(lines) + guide)
print("Generated docs/vehicle-catalog.md")
