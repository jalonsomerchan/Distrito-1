# Puerto Cobre: ciudad ampliada

El mapa ocupa **14.800 × 13.200 unidades**, unas **8,1 veces** la superficie anterior. Tiene **149 manzanas**, con **458 edificios**, **29 parques** y **25 descampados**. Mantiene la posición inicial y buena parte de la geometría del centro anterior para conservar los guardados. Seis parcelas incorporan una disposición diagonal.

## Barrios y naturaleza

Centro, Ribera Oeste, Polígono, Las Vegas, Ensanche, Los Jardines y Puerto Sur tienen tamaños y distribuciones de parcelas diferentes. El nombre del barrio aparece en el HUD. Las zonas verdes incluyen césped, caminos, árboles con colisión en el tronco, arbustos y mesas. Los descampados son superficies de tierra abiertas para conducir; el límite de velocidad de acera del vehículo también se aplica fuera de las calles.

El Río Cobre atraviesa el mapa de norte a sur y recibe el Brazo del Oeste. Sus orillas tienen muros y el agua tiene colisión. Solo se puede cruzar por los puentes. El minimapa distingue agua en azul, parques en verde y solares en marrón.

| Puente | Centro aproximado | Dirección |
| --- | --- | --- |
| Del Centro | 6650, 2060 | Oeste ↔ este |
| Industrial | 6650, 6160 | Oeste ↔ este |
| Del Sur | 6650, 10760 | Oeste ↔ este |
| De la Avenida | 765, 8100 | Norte ↔ sur |
| De Ribera | 5800, 8100 | Norte ↔ sur |

Los cinco puentes tienen tablero, barandillas visibles, colisión lateral y entradas abiertas. Las aberturas de la colisión del agua coinciden con la zona de paso. El camión de carga puede cruzarlos con su colisión completa.

## Cierre del mundo

Un dique amurallado de piedra de **160 unidades de grosor** rodea los cuatro lados. Las piezas se unen sin dejar esquinas abiertas. El cierre incluye las salidas de los cauces: son límites del dique, no pasos hacia fuera. Rocas y vegetación en el exterior refuerzan visualmente el límite. La cámara permite ver el muro; la colisión física impide atravesarlo incluso chocando a máxima velocidad.

Los guardados situados sobre agua, un muro o un objeto sólido se rechazan. Si pertenecen a una versión anterior del mapa, se devuelve el vehículo a la avenida inicial conservando su modelo, vida y progreso.

## Datos y rendimiento

- `data/city_layout.json`: parcelas, tipos de zona, barrios, cauces y puentes.
- `tools/generate_city_layout.py`: reproduce la distribución actual; sobrescribe el JSON al ejecutarse.
- `assets/environment/`: materiales y sprites generados del entorno, con manifiesto de extracción.
- `assets/raw/environment_*`: imágenes fuente y prompts.
- `tools/process_environment.py`: recorta el atlas y elimina el magenta de los elementos transparentes. No dibuja arte.

Las calles siguen siendo el espacio entre las aceras sobre un fondo liso; el puente es una estructura con su propio tablero, no un tileset de carreteras.

La flota está limitada a **64 vehículos** y, durante el juego normal, solo se simulan los que están a menos de **2500 unidades** del jugador. Los vehículos lejanos se ocultan y desactivan sus colisiones hasta acercarse; siguen conservando sus recorridos. Las pruebas pueden activar `traffic.simulate_all` para verificar toda la flota. El minimapa muestra el tráfico cercano activo. No se ha medido el rendimiento en una Steam Deck física.

## Comprobación

```sh
godot --headless --path . --script tests/city.gd
godot --headless --path . --script tests/world.gd
godot --headless --path . --script tests/traffic.gd
godot --headless --path . --script tests/truck.gd
```

La prueba de ciudad recorre el espacio libre para verificar que todas las avenidas, calles y puentes están conectados. La de mundo prueba los cuatro límites con choques rápidos, el bloqueo de las orillas y el paso del camión por los cinco puentes. Sin `--headless` también se generan capturas en `docs/`.


## Equipamiento urbano (versión 4)

La Playa del Cobre ocupa el tramo oeste del río entre `(6100, 3420)` y `(6530, 5220)`, con paseo, arena y mobiliario. Se abre la antigua orilla solo en ese tramo; el agua restante sigue bloqueada. Las rotondas del Ensanche, del Puerto y de Levante están en `(7400, 3510)`, `(7400, 8710)` y `(14135, 10230)`. Sus isletas de radio 65 tienen colisión circular y las rutas disponen de puntos de paso alrededor.

Los 12 semáforos están definidos en `data/city_details.json`. Cada eje tiene 12 segundos de verde, 2 de ámbar y 2 de despeje antes de dar paso al otro eje. El tráfico civil obedece la señal de su aproximación y los coches que ya están dentro despejan el cruce. Los pasos de peatones se pintan solo en aproximaciones abiertas. El ciclo se pausa y se guarda con la partida.

Capturas: `city-beach.png`, `city-roundabout.png` y `city-signals.png`. La prueba `tests/city_details.gd` comprueba colisiones, espacio para el camión, tráfico ante rojo y verde, continuidad de rutas y migración de guardados de los cuatro modos.
