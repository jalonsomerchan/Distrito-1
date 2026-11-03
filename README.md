# Distrito 01

Prototipo de conducción cenital para Godot 4.7. Abre `project.godot` y pulsa **F5** para ejecutar el proyecto completo. No necesita plugins.

Menú con selección entre seis vehículos, nueva partida y carga, 149 manzanas de tamaños variados, 458 edificios con colisión, minimapa, velocímetro, marcha atrás, freno de mano, pausa y guardado automático cada 30 segundos. Guardado también al iniciar partida, salir o volver al menú mediante su botón. Una única ranura: Nueva partida la reemplaza.

Al iniciar se elige ciudad: **Barcelona**, **París**, **Miami** o **Los Ángeles**. Cada destino tiene un trazado y paleta propios, tejados generados para esa ciudad y monumentos con colisión: Sagrada Familia, Torre Eiffel y Louvre, Freedom Tower y Griffith Observatory. París tiene el Sena y tres puentes; Miami, canales y calzadas; Barcelona, manzanas achaflanadas; Los Ángeles, supermanzanas y barrios de colinas. La ciudad seleccionada también se puede cambiar desde el menú y queda guardada en la partida.

## Modos de juego

**Nueva partida** abre un selector, compatible con teclado, ratón y mando:

- **Repartidor**: conduce al círculo amarillo y reduce la velocidad para recoger el paquete; después llévalo al círculo verde. El HUD indica la fase, el tiempo disponible, el nivel y las entregas completadas. El minimapa muestra la ruta por calles y puentes; una flecha junto al coche señala el objetivo.
- **Persecución**: conduces el interceptor policial y persigues a un fugitivo por las calles. Bloquea su paso o daña su coche con impactos; mantén ambos vehículos casi parados a menos de 145 unidades, con visión directa, durante 2–4 segundos para arrestarlo. El HUD muestra resistencia del fugitivo y porcentaje de arresto; aparece marcado en rojo en el minimapa y con una flecha. Cada arresto inicia un nivel más difícil tras tres segundos y repara la patrulla. Aumentan velocidad, aceleración, resistencia, ventaja inicial y tiempo de arresto; disminuye el margen antes de que escape. Si se aleja más de 2.500 unidades durante 5–10 segundos o la patrulla queda destrozada, termina la partida. Se guardan nivel, estado del fugitivo, ruta y progreso del arresto; la pausa congela la persecución.
- **Escape**: conduces tu coche y varias patrullas te persiguen, recalculando sus rutas por calles y puentes. Aléjate de todas las patrullas operativas al menos 1.800–2.200 unidades durante 8–12 segundos seguidos para escapar. Si una vuelve a acercarse, el progreso de huida se reinicia. Si te mantienen casi parado a menos de 145 unidades durante 1,7–3 segundos, con visión directa, te arrestan; destrozar tu coche también termina la partida. Puedes inutilizar patrullas mediante impactos. Cada huida completada inicia otro nivel con policías más rápidos, resistentes y próximos, y se añaden refuerzos hasta seis patrullas. El minimapa las marca en azul; el HUD muestra huida y arresto. La pausa congela todo y el guardado conserva el nivel, las patrullas y ambos progresos. Reparar con R / Y reinicia la persecución del nivel actual para evitar ganar huyendo mediante la recolocación.
- **Recogida rápida**: ve a por las monedas que aparecen de una en una en distintas zonas de la ciudad. Cada moneda tiene su propia cuenta atrás, calculada según la ruta por calles y puentes; al recogerla, aparece otra más lejos y con menos margen. El HUD y el minimapa señalan la moneda y la ruta. La partida termina cuando se agota el tiempo; se guarda la puntuación, la moneda actual y su tiempo restante.
- **Modo libre**: explora la ciudad sin objetivos ni cronómetros.

Cada fase tiene su propio plazo, calculado con la distancia de la ruta transitable, sus giros y la velocidad máxima del vehículo. Se estima una velocidad de crucero del 62% de la máxima, se añaden 0,9 segundos por giro y 6 segundos para maniobrar; el resultado recibe un margen inicial de 1,9 que disminuye con cada entrega (`1 + 0,9 / (1 + entregas × 0,16)`). Los siguientes encargos también favorecen distancias mayores, hasta un rango estable para partidas largas. Los puntos y rutas dejan espacio para el camión y rodean las barandillas de los puentes.

Para recoger o entregar hay que entrar en el círculo de 100 unidades y bajar de 65 u/s. Agotar cualquiera de los dos plazos termina la partida y permite reintentar o volver al menú. La pausa detiene el reloj; reparar el coche lo devuelve a la avenida sin reiniciar el encargo ni ampliar su plazo. El guardado conserva modo, fase, paquete, destinos, entregas y tiempo restante; las partidas antiguas se abren en modo libre.

## Controles

| Acción | Teclado | Steam Deck / mando |
| --- | --- | --- |
| Acelerar | W / ↑ | RT o A |
| Frenar / marcha atrás | S / ↓ | LT |
| Girar | A-D / ←→ | Stick izquierdo / cruceta |
| Freno de mano | Espacio | X |
| Reparar y recolocar en avenida | R | Y |
| Pausa | Esc | Start / ☰ |
| Guardar | F5 durante la partida | Menú de pausa |
| Pantalla completa | F11 | Configuración de Steam |
| Navegar por menús | Flechas / Tab + Enter | Stick / cruceta + A |

## Steam Deck

Resolución de referencia 1280 × 800, interfaz grande, mando sin ratón, zonas muertas para stick y gatillos, renderer Compatibility y exportación Linux x86_64. En Steam Input selecciona **Gamepad** para enviar los ejes y botones estándar al juego.

El preset **Steam Deck (Linux)** genera `build/linux/distrito-01.x86_64` con los recursos integrados. Desde Godot: Proyecto → Exportar → Steam Deck (Linux) → Exportar proyecto. Con las plantillas instaladas también puedes ejecutar:

```sh
mkdir -p build/linux
godot --headless --path . --export-release 'Steam Deck (Linux)'
```

Copia el ejecutable a la Deck, dale permiso de ejecución (`chmod +x distrito-01.x86_64`) y añádelo como juego externo a Steam. Es una compilación nativa de Linux. No incluye integración Steamworks ni certificación Steam Deck Verified. Falta la validación en una Deck física.

El guardado se almacena en `user://district_save.json`; en Linux suele estar en `~/.local/share/godot/app_userdata/Distrito 01/`. No se guarda dentro del directorio de instalación.

## Mundo ampliado: bosques y costa

El mundo mide **32.800 × 29.200 unidades**, **4,9 veces la superficie anterior**. La ciudad original conserva sus calles, edificios, puentes y semáforos, y se conecta con cuatro grandes zonas exteriores: Bosque del Norte, Pinar del Oeste, Bosque de Levante y Monte del Sur.

Hay **25 caminos de tierra**, entre accesos, circuitos, bifurcaciones y conexiones con la costa. Miden 320 unidades de ancho y dejan espacio para el camión. Los **5.069 árboles, 1.502 arbustos y 143 grupos de rocas** se colocan fuera de las zonas de paso; los troncos y las rocas tienen colisión. El minimapa muestra bosques, costa y caminos; el HUD indica la zona actual.

A la playa fluvial se suman **Playa del Faro**, **Cala del Pinar** y **Playa Brava**, con más de **44 millones de unidades cuadradas de arena** entre todas las playas. Incluyen paseos, sombrillas, tumbonas y bancos, y accesos de tierra hasta las proximidades del agua. El mar bloquea el paso de los coches.

Desde el centro puedes seguir la avenida del punto inicial hacia el norte o salir por el oeste a la altura de `y = 1300`. La costa está al este, entre `x = 19600` y `x = 21600`. Los encargos y las persecuciones también usan la nueva red; los destinos guardados de la ciudad conservan sus identificadores y coordenadas.

La vegetación se dibuja en lotes y carga solo los sectores próximos al coche (hasta 25 sectores de 1.024 unidades). Al cargar una partida lejana se actualizan sus colisiones inmediatamente. La validación de guardados consulta todos los troncos mediante un índice espacial, incluidos los sectores que no están cargados. No se ha medido el rendimiento en una Steam Deck física.

Datos y colocaciones: `data/wilderness.json`. `tools/generate_wilderness.py` reproduce la distribución con semilla fija usando los sprites y texturas existentes; no genera ilustraciones. Detalles y capturas en `docs/mundo-ampliado.md`.

## Más vida en la ciudad

- **12 cruces con semáforos**, ciclos de verde, ámbar y despeje; el tráfico civil frena con rojo y retoma la marcha con verde. Los cruces tienen pasos de peatones y líneas de detención. Los ejes opuestos nunca reciben verde a la vez. La pausa congela los ciclos y el guardado los conserva; el jugador y las persecuciones mantienen libertad para saltárselos.
- **Playa del Cobre**, una playa fluvial accesible junto a la orilla oeste: arena, paseo, sombrillas, tumbonas, bancos y vegetación. Está entre `(6100, 3420)` y `(6530, 5220)`. El agua que continúa a su lado conserva colisión; la arena aplica la velocidad de acera y aparece en el minimapa.
- **Tres rotondas**, en `(7400, 3510)`, `(7400, 8710)` y `(14135, 10230)`: isletas ajardinadas con colisión circular, bordillo y marcas de circulación. El anillo deja espacio al camión. Las rutas de reparto, fugitivos y patrullas rodean las isletas.

La versión 4 del mapa recoloca coches antiguos que queden dentro de una isleta y adapta los objetivos y rutas anteriores conservando progreso, niveles, vida y tiempos. Las nuevas colocaciones están en `data/city_details.json`, separadas del generador de manzanas. El arte nuevo se generó con `image_gen`: fuentes y prompts en `assets/raw/city_details*` y `assets/raw/beach_sand.png`; sprites en `assets/environment/`. `tools/process_city_details.py` reproduce únicamente la limpieza, el recorte y el escalado.

## Arte y escala

El núcleo urbano conservado mide **14.800 × 13.200 unidades**, dentro del nuevo mundo de **32.800 × 29.200**. Incluye siete barrios, **29 parques**, **25 descampados**, dos cauces conectados y **cinco puentes** transitables con el camión. Un dique amurallado rodea los cuatro lados y las orillas tienen colisión: no se puede salir del mapa ni entrar en el agua fuera de los puentes. El HUD muestra el barrio actual y el minimapa distingue agua, puentes, zonas verdes y solares. Detalles y coordenadas de los puentes en `docs/ciudad-ampliada.md`.

El camión **CAMIÓN DE CARGA** (`cargo_truck`) está disponible en el selector y en el tráfico de IA. Mide **58 × 148**, frente a 36 × 66 de un turismo, tiene colisión de **48 × 134**, **280 puntos de vida**, velocidad máxima de 360 u/s y aceleración de 120 u/s². Sus cinco estados están en `assets/sprites/truck_cargo*.png`; la hoja original está en `assets/raw/truck_cargo_sheet.png`. Los sensores, separaciones, radios de giro y anticipación de curvas de la IA tienen en cuenta el tamaño del modelo.

El catálogo central está en **`data/vehicles.json`**. Define ID, nombre, categoría, permisos de jugador/IA, velocidad máxima, aceleración, frenado, agarre, giro, marcha atrás, vida total, resistencia, dimensiones, sprites y parámetros de tráfico. El jugador y los bots consumen estos datos. Consulta `docs/vehicle-catalog.md` para ver los modelos y sus estadísticas; `docs/como-anadir-un-vehiculo.md` explica paso a paso cómo crear sprites y añadir vehículos de cualquier tamaño. El clásico está inicialmente reservado al jugador. Los guardados conservan el ID del modelo elegido.

La ciudad cuenta con una flota de hasta **64 vehículos de IA**, con simulación del tráfico cercano, repartidos entre los modelos habilitados en el catálogo. Circulan por la derecha, siguiendo circuitos alrededor de las manzanas, con curvas suaves, distintas velocidades y frenada antes de los giros. Detectan vehículos delante, frenan ante el jugador y retoman la marcha al despejarse el carril. Las trayectorias que se cruzan tienen prioridad entre conductores. Los coches tienen colisión física: los choques con el jugador afectan a su vida según la velocidad relativa. El tráfico también aparece en el minimapa y se congela al pausar.

Al iniciar o cargar, el tráfico se vuelve a distribuir dejando espacio alrededor del jugador; **R / Y** también despeja el punto de recuperación. Los vehículos de IA no se guardan individualmente.

Cada modelo tiene su propia vida total (entre 80 y 280 puntos), visibles con porcentaje y barra en la esquina inferior derecha. Los impactos descuentan vida según la velocidad perpendicular al obstáculo: un roce lateral hace menos daño que un choque frontal a la misma velocidad. El daño crece con la velocidad; los contactos muy suaves se ignoran y hay una breve protección de 0,35 s para evitar contar un mismo choque varias veces. Mantener el acelerador contra una pared no produce daño cada fotograma.

Cinco sprites: buen estado (más del 75%), daños leves (más del 50%), medios (más del 25%), graves (más del 0%) y destrozado (0%). A cero el coche se inmoviliza. **R / Y** lo repara y devuelve a la avenida. La vida se guarda con la partida; los guardados anteriores sin este dato se cargan con el coche sano. Los cinco turismos tienen sus cuatro sprites de daño (`car_XX_damage_1.png`–`car_XX_damage_4.png`): leve, medio, grave y destrozado. La hoja fuente de los estados está en `assets/raw/cars_damage_sheet_5x4.png`.

Los PNG originales generados están en `assets/raw/` y los sprites con transparencia, recortados y optimizados en `assets/sprites/`. Hay catorce variantes de azoteas (`building_01.png`–`building_14.png`), adaptadas a parcelas mucho mayores que los coches de 36 × 66 unidades, y cuatro pavimentos de acera con distintos adoquines y bordillos. Las 149 manzanas tienen diferentes anchuras y longitudes: las parcelas edificadas contienen entre 1 y 9 edificios y el resto se destina a parques o descampados. Seis manzanas incorporan una disposición diagonal de edificios y acera. Las avenidas continuas enlazan calles transversales desfasadas y cruces en T. La distribución editable está en `data/city_layout.json`; el minimapa refleja esta geometría. Las aceras conservan el grosor de sus bordillos y repiten el pavimento al cambiar de tamaño. Las calles son el espacio entre las aceras sobre un fondo liso: **no existe sprite de carretera**. Las marcas viales son primitivas gráficas. Si un guardado anterior queda dentro de un edificio nuevo, se conserva su progreso y vida y se devuelve el coche a la avenida inicial.

Las nuevas hojas de azoteas y aceras se generaron con `image_gen` en `assets/raw/`; `tools/process_city_variants.py` reproduce su recorte, limpieza del fondo y manifiesto.

`tools/process_assets.py` reproduce exclusivamente el recorte y la eliminación del fondo magenta con Pillow. No genera ilustraciones. El manifiesto incluye dimensiones y comprobación de márgenes.

## Comprobación

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/smoke.gd
godot --headless --path . --script tests/delivery.gd
godot --headless --path . --script tests/pursuit.gd
godot --headless --path . --script tests/escape.gd
godot --headless --path . --script tests/damage.gd
godot --headless --path . --script tests/city.gd
godot --headless --path . --script tests/city_details.gd
godot --headless --path . --script tests/world.gd
godot --headless --path . --script tests/wilderness.gd
godot --headless --path . --script tests/traffic.gd
godot --headless --path . --script tests/catalog.gd
godot --headless --path . --script tests/truck.gd
```

La prueba usa un guardado temporal separado y verifica menú, movimiento, giro, marcha atrás, colisiones, gatillo de mando, pausa, guardado/carga y rechazo de datos inválidos. Sin `--headless` también genera capturas de menú y juego en `docs/`.
