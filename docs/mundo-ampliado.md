# Bosques y costa — mundo versión 5

El límite pasa de `Rect2(-400,-400,14800,13200)` a `Rect2(-8400,-8400,32800,29200)`: 4,9025 veces la superficie anterior. La ciudad original ocupa `URBAN_BOUNDS` y conserva geometría, tráfico, puentes, rotondas y puntos de navegación. No se estiran sus calles ni sus parcelas para rellenar la ampliación.

| Zona | Rectángulo aproximado | Acceso |
| --- | --- | --- |
| Bosque del Norte | -7500, -7500, 27000, 6400 | Avenidas norte de Centro, Ensanche y Levante |
| Pinar del Oeste | -7500, -1000, 6400, 20000 | Salidas oeste en y = 1300 y y = 10500 |
| Bosque de Levante | 15000, -1000, 4500, 17500 | Salidas este en y = 2000 y y = 9000 |
| Monte del Sur | -1000, 13800, 20500, 6000 | Prolongaciones sur en x = 765, 7400 y 14135 |
| Playa del Faro | 19600, -6500, 2000, 9800 | Camino de la Costa; accesos en y = -4500 y 1600 |
| Cala del Pinar | 20500, 3400, 1100, 1100 | Acceso de tierra en y = 4000 |
| Playa Brava | 19800, 4700, 1800, 13000 | Accesos en y = 8000 y 15500 |

El Camino del Norte, el circuito del Sur y las sendas del oeste y de la costa enlazan los 25 trazados. La tierra usa la textura ya existente, aplicada con coordenadas UV del mundo para evitar estiramientos en curvas. Los accesos no llevan líneas viales urbanas. Las playas conservan claros alrededor de estos caminos para que el mobiliario no los bloquee.

Los 6.714 elementos naturales se distribuyen con semilla fija: 5.069 árboles, 1.502 arbustos y 143 grupos de rocas. La vegetación reutiliza el arte generado que ya había en `assets/environment/`. Se mantiene un margen libre alrededor de los caminos, incluidos los cruces y curvas, suficiente para la colisión completa del camión.

`wilderness.gd` agrupa plantas por sectores de 1.024 unidades y usa `MultiMeshInstance2D` para dibujarlas. Solo mantiene cargados hasta 25 sectores cercanos; cada sector agrupa sus colisiones estáticas. Un índice independiente de celdas de 256 unidades valida troncos y rocas aunque no estén cargados. Los arbustos son decorativos y transitables. El radio de carga cubre el campo visible y deja margen para conducir rápido.

La red añade puntos después de los identificadores originales y conecta todos los extremos de los caminos con el punto inicial. Los guardados de versión 4 conservan destinos y rutas; los anteriores siguen usando la migración de las rotondas. La cámara y el minimapa usan los límites nuevos, y cargar lejos refresca los sectores antes de conducir. El océano y el nuevo perímetro tienen colisión.

Datos: `data/wilderness.json`. Generador determinista de colocaciones: `python3 tools/generate_wilderness.py`. No crea ni modifica arte; compone los recursos existentes y emite posiciones y trazados.

## Verificación

`tests/wilderness.gd` comprueba superficie, acceso de camión a cada camino, conectividad de todos los extremos con la ciudad, coordenadas de navegación antiguas, guardados lejanos, colisión real de troncos y descarga de sectores. Las pruebas de ciudad, mundo, equipamiento urbano, tráfico, reparto, persecución, escape y conducción siguen siendo aplicables.

Capturas:

- `world-forest.png`: bosque del norte y curva de tierra.
- `world-west-trail.png`: vegetación del pinar y camino.
- `world-coast.png`: llegada de un acceso de tierra a la costa.
- `world-big-beach.png`: playa ampliada con paseo y mobiliario.
