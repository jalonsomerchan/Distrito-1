# Cómo crear y añadir un vehículo

El juego carga todos los modelos desde `data/vehicles.json`. Puedes añadir coches, furgonetas o camiones sin ampliar una lista de nombres ni modificar el selector. El tamaño visual y la colisión se configuran por modelo. El camión `cargo_truck` es el ejemplo completo ya integrado.

## 1. Crear los cinco sprites

Prepara cinco imágenes del **mismo vehículo**: nuevo, daños leves, medios, graves y destrozado. Usa vista cenital ortográfica, morro hacia arriba, iluminación y estilo coherentes con los coches existentes. Conserva escala, orientación y centro entre estados; las deformaciones no deben cambiar el encuadre.

Puedes pedir a Codex que genere una hoja con **una fila de cinco columnas iguales**, sobre fondo magenta puro `#FF00FF`, sin texto ni humo y con margen alrededor de cada vehículo. Por ejemplo:

> Genera una furgoneta de reparto cenital, morro arriba, estilo ilustrado HD de los vehículos del proyecto. Hoja de una fila con cinco celdas iguales: nueva, daños leves, medios, graves y destrozada. Mantén el mismo diseño, escala y centro en cada celda. Fondo magenta plano #FF00FF, margen en los cuatro lados, sin texto, perspectiva, humo ni piezas fuera de la celda.

Guarda el original en `assets/raw/delivery_van_sheet.png`. El camión existente usa `assets/raw/truck_cargo_sheet.png`; su prompt original está junto a la imagen, en `truck_cargo.prompt.txt`.

## 2. Separar las imágenes y eliminar el fondo

El procesador necesita Python 3 y Pillow (`python3 -m pip install Pillow`, preferiblemente dentro de un entorno virtual). Ejecuta desde la raíz del proyecto:

```sh
python3 tools/process_vehicle_sheet.py \
  --input assets/raw/delivery_van_sheet.png \
  --prefix delivery_van \
  --width 144 --height 336
```

Este script solo elimina el magenta, separa los cinco estados y los alinea con una escala compartida. No genera dibujos. Si alguna figura toca el borde de su celda, se detiene para que la regeneres con más margen.

Se crean estos archivos:

- `assets/sprites/delivery_van.png`
- `assets/sprites/delivery_van_damage_1.png` hasta `delivery_van_damage_4.png`
- `assets/sprites/delivery_van-manifest.json`, con recortes, escala y comprobación de bordes.
- `docs/delivery_van-stages.png`, una vista conjunta para revisar los estados.

Los cinco PNG tienen el mismo tamaño y transparencia. Revisa que desaparezca el fondo, que no queden bordes magenta y que el vehículo no cambie de tamaño al pasar de un estado a otro. También puedes preparar los cinco PNG a mano con esas mismas condiciones, sin utilizar el procesador.

## 3. Añadirlo al catálogo

Añade este objeto al final de `vehicles` dentro de `data/vehicles.json`, respetando las comas del JSON:

```json
{
  "id": "delivery_van",
  "name": "FURGONETA DE REPARTO",
  "category": "van",
  "description": "Vehículo mediano de carga, más grande y lento que un turismo.",
  "player_allowed": true,
  "bots_allowed": true,
  "draw_size": [48, 112],
  "collision_size": [38, 100],
  "max_speed": 400,
  "acceleration": 150,
  "reverse_speed": 120,
  "braking": 380,
  "grip": 8,
  "steering_rate": 1.3,
  "max_health": 200,
  "damage_multiplier": 0.7,
  "ai": {
    "cruise_min": 120,
    "cruise_max": 170,
    "acceleration": 75,
    "braking": 300,
    "corner_speed": 75,
    "spawn_weight": 2,
    "follow_distance": 80,
    "corner_lookahead": 100,
    "lane_offset": 65,
    "turn_radius": 56
  },
  "sprites": [
    "res://assets/sprites/delivery_van.png",
    "res://assets/sprites/delivery_van_damage_1.png",
    "res://assets/sprites/delivery_van_damage_2.png",
    "res://assets/sprites/delivery_van_damage_3.png",
    "res://assets/sprites/delivery_van_damage_4.png"
  ]
}
```

Los campos que omitas se heredan de `defaults`, también dentro de `ai`. La referencia completa está en `docs/vehicle-catalog.md`.

## 4. Ajustar tamaño, conducción y permisos

`draw_size` es el tamaño completo en el mundo de Godot, no la resolución del PNG. `collision_size` es el rectángulo físico completo, centrado en el mismo punto. Debe cubrir la carrocería, sin incluir espejos o espacio transparente. Conserva una proporción similar entre el lienzo PNG y `draw_size` para no deformar el sprite.

| Vehículo existente | Tamaño visual | Colisión | Vida |
| --- | --- | --- | ---: |
| Turismo | 36 × 66 | 27 × 53 | Según modelo |
| Camión de carga | 58 × 148 | 48 × 134 | 280 |

Las velocidades están en unidades/segundo y la aceleración/frenada en unidades/segundo². El HUD usa la conversión configurada en `units`. Un `grip` mayor corrige antes el deslizamiento lateral. Para un vehículo pesado, empieza con menor aceleración, velocidad y giro, y mayor vida. `damage_multiplier` por debajo de 1 reduce el daño recibido.

`player_allowed` controla si aparece en el selector. `bots_allowed` controla si puede aparecer como tráfico. Si habilitas bots, `spawn_weight` debe ser positivo; es un peso relativo, no una cantidad fija de unidades. El modelo por defecto debe estar habilitado para el jugador.

La IA calcula sensores y separación según la colisión real. Para un vehículo largo, aumenta `follow_distance` y `corner_lookahead`, reduce `corner_speed` y ajusta `turn_radius`. `lane_offset` mide la distancia entre el centro del vehículo y el borde de la manzana; no lo aumentes indiscriminadamente porque acercarías el vehículo al carril contrario. El camión usa 65, igual que los turismos, y un radio de giro de 64.

Un tamaño positivo no garantiza que quepa en las calles existentes. Revisa el rectángulo **girado**, incluyendo cabina y parte trasera, en las curvas y junto al tráfico contrario. Si no cabe, ajusta las rutas o la ciudad, o desactiva `bots_allowed` para ese modelo. No lo soluciones reduciendo la colisión hasta que deje de coincidir con la carrocería.

## 5. Importar, probar y actualizar documentación

Reinicia la ejecución para recargar el catálogo. En Godot, selecciona el modelo con el botón COCHE del menú y empieza una partida. Comprueba tamaño, giro, marcha atrás, choques, barra de vida y los cinco estados de daño. Al guardar se conserva su ID, incluso si cambias el orden del catálogo.

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/catalog.gd
godot --headless --path . --script tests/damage.gd
godot --headless --path . --script tests/traffic.gd
godot --headless --path . --script tests/truck.gd
python3 tools/export_vehicle_catalog.py
```

La prueba del catálogo comprueba IDs, estadísticas, permisos y rutas de sprites. La de tráfico comprueba la circulación; la del camión sirve como ejemplo de comprobación de un vehículo grande, incluyendo la huella girada a lo largo de sus rutas. Para un modelo nuevo grande, adapta ese caso a su ID y dimensiones y revisa también su aparición real en el tráfico.

## 6. Exportar para Steam Deck

```sh
mkdir -p build/linux
godot --headless --path . --export-release 'Steam Deck (Linux)'
```

El ejecutable queda en `build/linux/distrito-01.x86_64`, con el catálogo y los PNG incluidos. Para reproducir los sprites del camión ya integrado:

```sh
python3 tools/process_vehicle_sheet.py \
  --input assets/raw/truck_cargo_sheet.png \
  --prefix truck_cargo --width 174 --height 444
```
