# Randomizer y explorador de juegos para MiSTer FPGA

*[English](README.md) · Español · [Français](README.fr.md) · [Polski](README.pl.md) · [Svenska](README.sv.md)*

Dos cosas que comparten un pequeño servidor web en la MiSTer, ambas
pensadas para usarse desde el móvil:

**La página de seeds**: un generador de seeds y un tracker sin spoilers
para *A Link to the Past Randomizer* y *SMZ3* (Super Metroid + ALTTP
combinados). El mapa muestra por dónde has pasado y, lo más importante,
a qué puedes llegar de verdad con lo que llevas. La lógica de acceso es
**la de Archipelago**, el mismo conjunto de reglas que generó la seed.

**El explorador de juegos**: todos los juegos de tu MiSTer como una lista
en el móvil. Toca un juego y la MiSTer cambia de core y lo inicia. Los
sistemas con solo unos pocos juegos se agrupan tras una única casilla para
que la página de inicio siga siendo legible.

> **No se incluye ninguna ROM, ni puede incluirse.** El explorador muestra
> lo que ya está en tu propia tarjeta SD; si no tienes juegos ahí, verás
> una lista vacía. Lo mismo vale para las ROM base de la generación de
> seeds: tienen que ser tus propios volcados. Consulta *Tus propias ROM*
> más abajo.


<p align="center">
  <img src="docs/seed-page.png" alt="La página de seeds con dos partidas una al lado de la otra" width="900">
</p>

<p align="center">
  <img src="docs/map-light-world.png" alt="El mapa del Mundo de la Luz con contadores de mazmorras" width="440">
  <img src="docs/map-zebes.png" alt="El mapa de Zebes con las ubicaciones recogidas" width="440">
</p>

<p align="center">
  <em>Verde se puede alcanzar ahora, rojo está bloqueado, gris está hecho.
  Las etiquetas cuentan los cofres que quedan en cada mazmorra. Los jefes
  son rombos y se vuelven grises en cuanto caen. Aquí se muestra en sueco;
  también incluye inglés, español, francés y polaco.</em>
</p>

<p align="center">
  <img src="docs/item-grid.png" alt="Una tarjeta de ALTTPR y otra de SMZ3 una al lado de la otra, cada una con su cuadrícula de objetos" width="900">
</p>

<p align="center">
  <em>Lo que has recogido, iluminado al encontrarlo y con la cantidad en la
  esquina; una tarjeta de SMZ3 muestra ambos juegos. Los iconos de la
  imagen son la copia propia del jugador; consulta
  <a href="#qué-no-se-incluye">Qué no se incluye</a>.</em>
</p>

<p align="center">
  <img src="docs/leaderboard-smz3.png" alt="La clasificación de SMZ3: cinco seeds completadas ordenadas por tiempo total, con los tiempos de Zelda y Metroid de cada una" width="900">
  <img src="docs/leaderboard-alttpr.png" alt="La clasificación de ALTTPR con una seed completada" width="900">
</p>

<p align="center">
  <em>Una clasificación para cada juego, con la seed completada más rápida
  primero. SMZ3 muestra el tiempo de cada mitad junto al total, los mismos
  tiempos que aparecen en los créditos. «≈» indica un tiempo leído después
  del archivo de guardado, no en la meta.</em>
</p>

<p align="center">
  <img src="docs/game-browser.png" alt="El explorador de juegos con todos los sistemas de la tarjeta" width="900">
</p>

---

## Qué necesitas

**Dos máquinas, nada más:**

1. Una **MiSTer FPGA** en tu red.
2. Un servidor de **Home Assistant**: *Home Assistant OS* o *Supervised*.
   Es un requisito imprescindible: HA Container y HA Core no pueden
   instalar complementos, y la lógica es un complemento.

### Tus propias ROM

El explorador de juegos no necesita nada: muestra los juegos que ya tienes
en `/media/fat/games/`.

**La generación de seeds** necesita dos volcados sin cabecera que debes
poseer y volcar tú mismo:

```
alttp.smc   1 048 576 bytes   md5 03a63945398191337e896e5771f77173
sm.smc      3 145 728 bytes   md5 21f3e98df4780ee1c667b84e57d88675
```

(Zelda 3 japonés 1.0 y Super Metroid JU, respectivamente.) El instalador
los busca entre tus propias ROM de SNES, también dentro de archivos `.zip`
e incluso si llevan una cabecera de 512 bytes, así que normalmente no
tienes que hacer nada.

---

## Instalación

Las dos mitades son independientes y se pueden instalar en cualquier
orden. Aun así, empieza por Home Assistant: así el instalador de la MiSTer
puede comprobar que la lógica responde antes de darse por terminado.

### 1. Home Assistant

1. **Ajustes → Complementos → Tienda de complementos**
2. Menú de arriba a la derecha → **Repositorios** → pega:
   ```
   https://github.com/frystien-png/mister-randomizer
   ```
3. Cierra el diálogo, busca **SMZ3 and ALTTPR logic** → **Instalar**
4. Pestaña **Configuración** → escribe la dirección IP de la MiSTer → **Guardar**
5. **Iniciar**

La primera compilación tarda unos minutos: en ese momento se descarga y
se recorta Archipelago.

*Sin GitHub:* copia la carpeta `smz3-logic/` en `/addons/` de Home
Assistant (con el complemento Samba o SSH), elige **Buscar
actualizaciones** en el menú de la tienda de complementos y aparecerá en
**Complementos locales**.

### 2. MiSTer

Coloca **un solo archivo** en `/media/fat/Scripts/` de la tarjeta SD; el
resto lo descarga él mismo:

```
https://raw.githubusercontent.com/frystien-png/mister-randomizer/main/mister/Randomizer_install.sh
```

Después ejecuta **Scripts → Randomizer_install** desde el menú de la
MiSTer.

*Sin internet en la MiSTer:* pon `randomizer-payload.tar.gz` junto al
script y se usará en lugar de la descarga.

El instalador encuentra Home Assistant por su cuenta, coloca los archivos,
te pregunta qué idioma quieres, crea las entradas del menú, configura el
arranque automático e inicia el servidor. Puedes volver a ejecutarlo
cuando quieras: tus notas, marcadores del mapa y tiempos de llegada no se
tocan, y una instalación existente no se sobrescribe.

---

## Idioma

Las páginas se traducen al servirse. El inglés es el idioma por defecto;
el instalador pregunta y la elección se guarda en
`.mistergames/randomizer.conf`:

```
MISTER_LANG="es"
```

Cambia esa línea y reinicia la MiSTer para cambiar de idioma; no hace
falta reinstalar.

| Código | Idioma |
|---|---|
| `en` | English *(el idioma original y el predeterminado)* |
| `es` | Español |
| `fr` | Français |
| `pl` | Polski |
| `sv` | Svenska |

### Añadir tu propio idioma

Todo lo que necesitas ya está en la MiSTer, en
`/media/fat/Scripts/.mistergames/lang/`:

1. Copia `TEMPLATE.json` a `<código>.json`, por ejemplo `de.json`.
2. Pon en `__name` el nombre del idioma en su propio idioma (`"Deutsch"`).
3. Traduce la parte **derecha** de cada línea. La parte izquierda es el
   texto original en inglés y no debe cambiarse nunca: es la clave con la
   que se busca en la página.
4. Lo que dejes sin traducir se queda en inglés, así que una traducción a
   medias funciona perfectamente.
5. Vuelve a ejecutar el instalador y elige tu idioma en el menú: muestra
   todos los archivos que haya en la carpeta.

Junto a los archivos de idioma hay dos herramientas:

```
python3 lang_check.py          comprueba todos los archivos de idioma
python3 lang_extract.py        regenera la plantilla a partir de las páginas
```

`lang_check.py` es la que vale la pena ejecutar. Indica cuánto de la
plantilla has cubierto y falla ante los dos errores que de verdad rompen
algo: una clave que no aparece en las páginas (casi siempre una errata;
basta con que falte un espacio final) y una clave que también se usa como
clase CSS o nombre de archivo, lo que traduciría la mecánica de la página
en vez de su texto.

Los nombres de objetos de Zelda (Arco, Gancho, Perla lunar) se traducen en
todos los idiomas. Los de Super Metroid (Morph Ball, Screw Attack,
missiles) quedan **en inglés en todas partes**: el juego nunca se tradujo
y los jugadores conocen esos nombres en inglés, hablen el idioma que
hablen.

Las traducciones pueden contener apóstrofos y comillas (`l'écran`,
`¿Qué?`); se escapan según el lugar donde acaban.

---

## Cómo se usa

| | |
|---|---|
| **Explorador de juegos** | `http://<ip-de-la-mister>:8182/` |
| **Página de seeds** | `http://<ip-de-la-mister>:8182/seeds` |
| **Volver al menú** | el botón `⏏ Menú` de la cabecera, visible mientras hay un juego en marcha |
| **Nueva seed de ALTTPR** | menú de la MiSTer → Scripts → `ALTTPR_new_seed` |
| **Nueva seed de SMZ3** | menú de la MiSTer → Scripts → `SMZ3_new_seed` |

Añade las dos páginas a Home Assistant como tarjetas de tipo **página
web** con la dirección de la MiSTer y podrás abrirlas desde el móvil.

Los juegos en archivos `.zip` funcionan igual que los sueltos: el lanzador
resuelve la ruta dentro del archivo, que es lo que exige un MGL. Una
colección que mezcle ambos no da problemas.

El explorador vuelve a indexar las carpetas de juegos cada quince minutos,
y al instante si llamas a `http://<ip-de-la-mister>:8182/api/rescan`. Los
juegos nuevos aparecen solos, sin reiniciar.

---

## Lectura en directo (SNI)

El instalador ofrece configurar **SNI**, que permite al servidor leer
directamente la memoria del juego. Así el mapa se actualiza **mientras
juegas**, y no solo cuando abres el menú OSD.

Se apoya en un soporte que ya existe en el core oficial de SNES de MiSTer
(desde marzo de 2026) y en el programa principal (desde abril). Lo que
falta es el daemon [`snid`](https://github.com/NobodyNada/snid), que el
instalador descarga y comprueba con una suma de verificación conocida.

**Un paso que tienes que hacer tú, una sola vez:** inicia un juego de
SNES, abre el menú OSD y elige **UART MODE → SNI**. El modo lo envía al
core el menú, no un archivo, así que no se puede hacer por ti. La elección
se guarda por core y se restaura automáticamente después.

Comprueba que funciona con `curl http://<mister>:8182/api/smz3`: el campo
`live` debe ser `true` para la seed en marcha.

⚠️ En una MiSTer que ya tenga su tiempo, el archivo del sistema
`/usr/sbin/uartmode` puede estar demasiado anticuado y no conocer el modo
SNI. El instalador lo detecta y pregunta antes de tocar nada; el original
se guarda como `uartmode.original` en la tarjeta SD. Una actualización de
firmware futura puede sobrescribir el cambio: basta con volver a ejecutar
el instalador.

Si te saltas SNI, todo lo demás sigue igual; el archivo de guardado sigue
siendo la fuente.

---

## Lo que conviene saber de antemano

**Sin SNI, el archivo de guardado solo se escribe al abrir el menú OSD.**
La MiSTer vuelca la memoria de guardado del juego a la tarjeta SD en ese
momento, no de forma continua. Por eso el tracker no puede ver nada de lo
que hayas hecho desde la última vez que abriste el menú. Un hábito que
merece la pena: **abre y cierra el OSD después de guardar.**

Por el mismo motivo: **no inicies un juego nuevo desde el explorador en
mitad de una partida** sin abrir antes el OSD. El cambio de core es
inmediato y se pierde todo lo posterior al último volcado; eso vale para
todos los juegos, no solo para las seeds del randomizer. No se puede
arreglar por software: `/dev/MiSTer_cmd` solo entiende `load_core` y unos
pocos comandos de vídeo y audio, sin forma de abrir el menú ni de pedir un
guardado.

**Da direcciones fijas a las dos máquinas** en tu router. Si alguna cambia
de IP dejan de encontrarse, y eso se nota en un mapa que no se actualiza,
no en un mensaje de error.

---

## Si algo va mal

| Síntoma | Causa probable |
|---|---|
| La página no responde en absoluto | El servidor no está en marcha. Vuelve a ejecutar `Randomizer_install`. |
| Un juego arranca pero la pantalla se queda en negro | Casi siempre son los ajustes de vídeo de la propia MiSTer, no esto. Un `video_mode` fijo junto con `vsync_adjust=1` emite 50 Hz para los juegos PAL, y muchos televisores rechazan ese modo: el juego está en marcha, solo que no lo ves. Revisa la carpeta de guardados: si apareció `saves/<core>/<juego>.eep` o `.sra`, la ROM sí se cargó. Se arregla con `vsync_adjust=0` en `MiSTer.ini`. |
| El mapa se ve pero los puntos no tienen color | El complemento no responde. Revisa su registro y `mister_ip`. |
| El mapa no se actualiza después de jugar | No has abierto el OSD. El archivo de guardado no se ha volcado. |
| Partes de la página salen en inglés | Ese archivo de idioma aún no traduce esos textos; se quedan en inglés. Ejecuta `lang_check.py`. |
| «ROM incorrecta» con el juego correcto | Tienes otro volcado. Compara el md5 con la lista de arriba. |
| No pasa nada tras reiniciar la MiSTer | `user-startup.sh` no puede llamarse `_user-startup.sh`. |
| La descarga falla en la MiSTer | Lista de certificados antigua. Ejecuta **Scripts → update_all** una vez, o pon `randomizer-payload.tar.gz` junto al script. |

Registro en la MiSTer: `/tmp/mistergames.log`.
Servicio de lógica: `curl http://<home-assistant>:8183/health`.

**¿Sigues atascado o tienes una idea?** Pregunta en
[Discussions](https://github.com/frystien-png/mister-randomizer/discussions).
Preguntas, peticiones y «así lo tengo montado yo» son bienvenidos; no hace
falta abrir un issue.

---

## Qué *no* se incluye

**Ninguna ROM, ninguna imagen de disco, nada con derechos de autor.** El
paquete es código y tablas de datos. Lo garantiza `check_payload.sh`, que
se ejecuta en cada compilación y se niega a empaquetar nada que parezca
una ROM. Puedes ejecutarlo tú mismo sobre el archivo descargado:

```
./check_payload.sh randomizer-payload.tar.gz
```

Rechaza extensiones de ROM, todo lo que haya en `randomizer/base/` salvo
la nota, archivos de más de 400 K, binarios de tipo desconocido, secretos
y estado de usuario que no esté vacío. También rechaza **datos privados de
red** (direcciones RFC 1918, direcciones MAC, nombres de recursos
compartidos, tokens y claves) para que la red doméstica de nadie se
filtre con una versión.

También quedan fuera del paquete: el estado del core enviado a Home
Assistant (`ha_push.py`) y el montaje por NAS de discos de PS1/Saturn
(`nas_mount.sh`). El explorador muestra lo que esté montado en
`/media/fat/games/`, así que tu propio montaje de red funciona, pero
configurarlo te toca a ti.

Si ya tienes tu propio `page.py`, el instalador no lo toca y deja el suyo
al lado como `page.py.new`.

**Sin iconos de objetos.** Cada tarjeta de seed tiene una cuadrícula de lo
que has recogido, dispuesta como en los trackers de la comunidad. Los
iconos son gráficos de los propios juegos, así que no pueden incluirse;
sin ellos, cada casilla muestra una palabra corta y la cuadrícula funciona
igual. Para tener imágenes, pon PNG de 32×32 en una carpeta `items/` junto
a la página de seeds (en Home Assistant, `/config/www/items/`). Los nombres
de archivo son los que piden `invZelda`/`invMetroid` en `seedpage.py`:
`bow1.png`, `sword3.png`, `sm-Morph.png`, etc.

---

## Licencia y créditos

Este proyecto tiene **licencia MIT**; consulta [LICENSE](LICENSE). Úsalo,
modifícalo y redistribúyelo; conserva el aviso de copyright y no esperes
ninguna garantía.

Se apoya en el trabajo de otros:

| | |
|---|---|
| [Archipelago](https://github.com/ArchipelagoMW/Archipelago) (MIT) | la propia lógica de acceso. El complemento la fija a un commit exacto y responde con sus reglas, no con reglas nuestras. |
| [hutchch/ALTTPR-Tracker](https://github.com/hutchch/ALTTPR-Tracker) (MIT) | la tabla de cofres que asocia cada ubicación de ALTTP con su indicador exacto en la SRAM, y la forma de tratar la elección de medallón. |
| [TotalSMZ3](https://github.com/tewtal/SMZ3Randomizer) | la lógica de SMZ3 y la estructura de ROM que sigue la versión combinada. |
| [pyz3r](https://github.com/tcprescott/pyz3r) (Apache-2.0) | tres archivos incluidos para aplicar parches de ALTTPR. Modificado: aiohttp sustituido por urllib, porque la MiSTer no tiene pip. La licencia y el NOTICE van dentro del paquete. |
| [bps](https://pypi.org/project/bps/) (WTFPL) | aplicación de parches BPS incluida. COPYING va dentro del paquete. |
| [snid](https://github.com/NobodyNada/snid) de NobodyNada | el daemon que hace posible leer en directo la memoria de SNES. Se descarga a petición, nunca se incluye. |
| alttpr.com y samus.link | generación de seeds y los sprites. Solo se intercambian datos de parche; nunca se sube ninguna ROM. |
| Las capturas de pantalla | Los mapas bajo los puntos son ilustraciones de los propios juegos (© Nintendo); el mapa de Zebes es obra de Falcon Zero. Ilustran el tracker; este proyecto no incluye ningún dato de juego. |

**No se incluye ningún dato de juego de ningún tipo**; consulta el
apartado *Qué no se incluye* más arriba.

## Para quien quiera construir sobre esto

```
├── repository.yaml          debe estar en la raíz - HA lo busca ahí
├── smz3-logic/              el propio complemento
│   ├── config.yaml          opciones, puertos, arquitecturas
│   ├── Dockerfile           descarga y recorta Archipelago
│   └── logic/               reachd.py, smz3_logic.py, alttp_locmap.py
├── mister/
│   ├── Randomizer_install.sh
│   └── randomizer-payload.tar.gz
├── build_payload.sh         reconstruye el paquete desde una MiSTer en marcha
└── check_payload.sh         el guardián: sin ROM, sin secretos, sin datos de la red local
```

La MiSTer es la fuente de verdad del paquete: el código vive allí y
`build_payload.sh` lo copia a casa, dejando fuera todo lo personal: ROM,
contraseñas, notas privadas. Se niega a funcionar sin una dirección:

```
./build_payload.sh 192.168.1.50
echo 192.168.1.50 > .mister-ip     # ignorado por git, se recuerda para la próxima vez
```

No se empaqueta nada hasta que el guardián ha dado su visto bueno. Si
encuentra algo, la compilación se detiene y el tarball existente queda
intacto.

El instalador se puede ensayar sin tocar una instalación real:

```
FAT=/tmp/prov ./Randomizer_install.sh
```

No se toca nada en marcha y todo acaba en `/tmp/prov`.
