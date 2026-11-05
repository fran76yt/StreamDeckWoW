<p align="center">
  <img src="StreamDeck/com.fsegado.wowdeck.sdPlugin/imgs/plugin.png" width="128" alt="StreamDeck WoW">
</p>

# StreamDeck WoW — Léeme

<p align="center">
  <b>¿Te gusta el proyecto? Sígueme para no perderte las novedades.</b><br>
  <a href="https://www.youtube.com/@fran_76"><img src="https://img.shields.io/badge/YouTube-Suscr%C3%ADbete-FF0000?style=for-the-badge&logo=youtube&logoColor=white" alt="Suscríbete en YouTube"></a>
  <a href="https://www.twitch.tv/fran76"><img src="https://img.shields.io/badge/Twitch-S%C3%ADgueme-9146FF?style=for-the-badge&logo=twitch&logoColor=white" alt="Sígueme en Twitch"></a>
  <a href="https://x.com/fran76yt"><img src="https://img.shields.io/badge/X-@fran76yt-000000?style=for-the-badge&logo=x&logoColor=white" alt="Sígueme en X"></a><br>
  <sub>Si te sirve, una suscripción o un follow es la mejor forma de apoyarlo. ⭐ Y una estrella en GitHub también ayuda.</sub>
</p>

---

Controla **World of Warcraft: Forever** desde una **Stream Deck**: cada tecla lanza un hechizo, usa un objeto o ejecuta una macro, y muestra su icono. Lo que hace cada tecla se configura **dentro del juego**, arrastrando hechizos a una ventana, y la Stream Deck se actualiza sola.

El proyecto tiene tres piezas que trabajan juntas:

| Pieza | Qué es | Dónde está |
|---|---|---|
| **Addon StreamDeck WoW** | Addon de WoW que convierte los atajos de la Stream Deck en hechizos, objetos o macros | La raíz de este repositorio |
| **Plugin WoW Deck** | Plugin de Stream Deck que pinta cada tecla con el icono correcto y envía el atajo al pulsarla | [`StreamDeck/com.fsegado.wowdeck.sdPlugin`](StreamDeck/com.fsegado.wowdeck.sdPlugin) |
| **Perfil «WoW Forever»** | Perfil de Stream Deck + que se activa solo al poner WoW en primer plano | Se genera con [`StreamDeck/profile`](StreamDeck/profile) |

> **Estado:** versión **0.1.0**, en pruebas. Probado con WoW Forever 1.60.1 (la lista de addons lo acepta sin marcarlo como incompatible) y Stream Deck 7.6.1. Todo el flujo está probado con una API del juego simulada; la prueba completa dentro del mundo está pendiente.

---

## Índice

1. [La idea en una imagen](#1-la-idea-en-una-imagen)
2. [Por qué está hecho así](#2-por-qué-está-hecho-así)
3. [Cómo funciona, paso a paso](#3-cómo-funciona-paso-a-paso)
4. [El addon por dentro](#4-el-addon-por-dentro)
5. [El plugin por dentro](#5-el-plugin-por-dentro)
6. [El contrato entre addon y plugin](#6-el-contrato-entre-addon-y-plugin)
7. [Los atajos de teclado](#7-los-atajos-de-teclado)
8. [El perfil de Stream Deck](#8-el-perfil-de-stream-deck)
9. [Requisitos](#9-requisitos)
10. [Instalación](#10-instalación)
11. [Uso](#11-uso)
12. [Huecos por defecto](#12-huecos-por-defecto)
13. [Estructura del proyecto](#13-estructura-del-proyecto)
14. [Desarrollo](#14-desarrollo)
15. [Diagnóstico y solución de problemas](#15-diagnóstico-y-solución-de-problemas)
16. [Limitaciones conocidas](#16-limitaciones-conocidas)

---

## 1. La idea en una imagen

```
                 ┌──────────────────────── WoW Forever ───────────────────────┐
                 │                                                            │
  Pulsas una     │   Addon StreamDeck WoW                                     │
  tecla de la    │   ───────────────────                                      │
  Stream Deck    │   Ctrl+Alt+Mayús+F3  ──(override binding)──>  Llamar a     │
       │         │                                               mascota      │
       ▼         │                                                            │
 ┌───────────┐   │   /sdeck config ──> guarda los huecos en StreamDeckWoWChar │
 │  Plugin   │   │                         │                                  │
 │  WoW Deck │   └─────────────────────────┼──────────────────────────────────┘
 │           │                             │  /reload, cerrar sesión o salir:
 │ envía     │──── Ctrl+Alt+Mayús+F3 ────> │  WoW escribe el archivo
 │ el atajo  │     (teclado de Windows)    ▼
 │           │                  WTF\...\SavedVariables\StreamDeckWoW.lua
 │ pinta la  │<──── lo lee cuando cambia ──────────┘
 │ tecla     │      (mira su fecha cada 1,5 s)
 └───────────┘──── descarga el icono de Wowhead (una vez, con caché)
```

- **De la Stream Deck al juego** la comunicación es por **teclado**: el plugin pulsa un atajo y el addon decide qué hace ese atajo.
- **Del juego a la Stream Deck** es por **archivo**: el addon deja en sus *SavedVariables* qué hay en cada hueco y el plugin lo lee.

---

## 2. Por qué está hecho así

Cada decisión responde a una limitación concreta del juego o de Stream Deck.

**WoW no deja que un programa externo lance hechizos.** Es intencionado, para impedir bots. Lo único que puede hacer la Stream Deck es pulsar teclas, como un teclado. Por eso el plugin envía un atajo y la lógica de «qué hechizo es» vive dentro del juego, en el addon.

**Un addon no puede abrir archivos ni conexiones de red.** Está encerrado en el juego. Lo único que puede sacar fuera son sus **SavedVariables**: variables que WoW guarda en disco al hacer `/reload`, al cerrar sesión o al salir. Ese archivo es el canal del juego hacia la Stream Deck.

**Un plugin de Stream Deck no puede pulsar teclas mediante la aplicación ni cambiar el icono de las acciones propias de Elgato.** El SDK solo permite al plugin cambiar la imagen, el título y el estado de *sus* teclas ([referencia del SDK](https://docs.elgato.com/streamdeck/sdk/references/websocket/plugin)). Si queremos que una tecla cambie de icono sola, esa tecla tiene que ser del plugin, y entonces también tiene que ser el plugin quien envíe la pulsación.

**Sin el plugin todo seguiría funcionando en el juego**: bastaría con teclas de atajo normales de Stream Deck que envíen `Ctrl+Alt+Mayús+F1…F12`. Lo que aporta el plugin es que los iconos y nombres de las teclas reflejen lo configurado en el juego, que las habilidades que aún no tienes se vean en gris y que un único perfil sirva para todos tus personajes.

---

## 3. Cómo funciona, paso a paso

### 3.1. Al entrar con un personaje

1. WoW carga los archivos del addon en el orden del [`.toc`](StreamDeckWoW.toc) y recupera sus SavedVariables (`StreamDeckWoWChar`) del disco.
2. Con el evento `PLAYER_LOGIN`, el addon averigua la clase del personaje (por su nombre interno en inglés, `HUNTER`, que no depende del idioma).
3. Para cada uno de los 12 huecos decide qué asignar ([`Core/Slots.lua`](Core/Slots.lua)):
   - si lo has configurado tú, lo tuyo;
   - si no, el valor por defecto de tu clase o, si no lo hay, el común ([`Defaults/`](Defaults));
   - de una lista de hechizos, el primero que conozcas; de una lista de objetos, el primero que lleves en las bolsas (así la tecla de poción usa siempre la mejor que tengas).
4. Asigna cada hueco a su atajo con **override bindings** ([`Core/Bindings.lua`](Core/Bindings.lua)). El hueco 3 queda como `ALT-CTRL-SHIFT-F3 → Llamar a mascota`.
5. Guarda una **foto** de los 12 huecos en `StreamDeckWoWChar.slots` (nombre, tipo, ID, icono, si está disponible) para el plugin. «Disponible» quiere decir que tienes lo asignado: el hechizo aprendido o el objeto en las bolsas.
6. Escribe en el chat un resumen: *«7 de 12 teclas listas»* (las asignadas y disponibles).

A partir de ahí recalcula solo cuando hace falta: al aprender o perder hechizos (`SPELLS_CHANGED`), al cambiar las bolsas (`BAG_UPDATE_DELAYED`) o las macros (`UPDATE_MACROS`), y cuando el servidor envía los datos de un objeto que el addon pidió porque el cliente aún no los tenía (`GET_ITEM_INFO_RECEIVED`; ese evento llega también por cualquier otro objeto que cargue el cliente, y esos se ignoran). Esos eventos llegan en ráfagas, así que se agrupan: la actualización se ejecuta medio segundo después del primero de la ráfaga.

### 3.2. Al pulsar una tecla de la Stream Deck

1. Stream Deck avisa al plugin con el evento `keyDown` de esa tecla.
2. El plugin mira qué hueco representa la tecla (un ajuste guardado en el perfil, `{ "slot": 3 }`).
3. Pide al proceso auxiliar ([`helper.ps1`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/helper.ps1)) que pulse `Ctrl + Alt + Mayús + F3`.
4. El auxiliar comprueba qué modificadores estás pulsando ya con la mano, pulsa solo los que faltan más la F3, la mantiene 30 ms y suelta lo que pulsó él ([`WowDeckKeys.cs`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/native/WowDeckKeys.cs)).
5. Windows entrega la pulsación a la ventana con el foco: WoW.
6. WoW encuentra el override binding del addon y lanza **Llamar a mascota**.

La pulsación es idéntica a la de un teclado: una pulsación, una acción.

### 3.3. Al cambiar un hueco en el juego

1. Abres la ventana con `/sdeck config` ([`UI/ConfigWindow.lua`](UI/ConfigWindow.lua)).
2. Arrastras un hechizo del libro, un objeto de las bolsas o una macro a un hueco ([`UI/SlotButton.lua`](UI/SlotButton.lua)). El addon lee qué llevas en el cursor y lo guarda en `StreamDeckWoWChar.custom[n]`. Otras cosas (monturas, acciones de mascota…) no se aceptan. Lo que arrastras se asigna aunque todavía no lo tengas, para que la tecla funcione en cuanto lo aprendas o lo consigas; mientras tanto su icono sale en gris en la ventana y en la Stream Deck, y en rojo en `/sdeck` y en el tooltip, igual que un valor por defecto que aún no tienes.
3. El cambio **funciona en el juego al momento** (en combate, al terminar la pelea): el addon reasigna los atajos.
4. Para que la Stream Deck lo vea, pulsas **Actualizar Stream Deck** (hace `/reload`). WoW escribe las SavedVariables en disco.
5. El plugin, que mira cada 1,5 segundos la fecha de modificación del archivo, ve que ha cambiado, lo lee y repinta las teclas.
6. Si un icono no está en su caché, lo pide a Wowhead: primero el nombre del icono a partir del ID del hechizo u objeto y después la imagen. Lo guarda en disco y no vuelve a descargarlo.

### 3.4. Durante el combate

WoW bloquea los cambios de atajos en combate. Si algo cambia en mitad de una pelea (te bebes la última poción, por ejemplo), el addon lo deja pendiente y lo aplica al salir de combate (`PLAYER_REGEN_ENABLED`). Las teclas siguen funcionando con lo que tenían asignado.

### 3.5. Con varios personajes

Cada personaje guarda su configuración en su propio archivo de SavedVariables. El plugin muestra siempre el archivo **guardado más recientemente**. Por eso basta un perfil de Stream Deck para todas las clases.

Hay un matiz: WoW escribe el archivo de un personaje al recargar la interfaz, cerrar sesión o salir del juego, **no al entrar**. Si sales con el personaje A y entras con el B, se guarda el archivo de A, y la Stream Deck sigue mostrando a A hasta que guardes el de B. Para que muestre al personaje con el que acabas de entrar, haz un `/reload` (o pulsa **Actualizar Stream Deck** en `/sdeck config`). Las teclas funcionan igual en el juego mientras tanto: lo que se queda desfasado son solo los iconos y nombres de la Stream Deck.

---

## 4. El addon por dentro

Todos los archivos del addon reciben la misma tabla privada (`local _, ns = ...`), que hace de espacio de nombres compartido sin llenar el espacio global, donde podría chocar con otros addons. Las únicas globales son las que exige WoW (el comando `SLASH_STREAMDECKWOW1`, el nombre de la ventana, `StreamDeckWoWConfig`, para cerrarla con Escape, y el del botón del minimapa, `StreamDeckWoWMinimapButton`, que reconocen los addons que ordenan los botones del minimapa) y `StreamDeckWoW`, que expone esa tabla para inspeccionarla en el juego con `/dump`. Cada módulo se cuelga de ella (`ns.Slots`, `ns.Bindings`…) y usa los que se han cargado antes.

| Archivo | Responsabilidad |
|---|---|
| [`Core/Constants.lua`](Core/Constants.lua) | Todos los valores fijos: número de huecos, modificadores del atajo, eventos, colores, medidas de la ventana y del botón del minimapa |
| [`Core/Util.lua`](Core/Util.lua) | Utilidades genéricas, reutilizables en otros addons (solo dependen de las constantes): suscripción a eventos, mensajes entre módulos, *debounce*, ejecutar fuera de combate, escribir en el chat |
| [`Core/Keys.lua`](Core/Keys.lua) | Traduce un hueco a su atajo (`ALT-CTRL-SHIFT-F3`) y a su texto legible (`Ctrl+Alt+Mayús+F3`) |
| [`Core/Api.lua`](Core/Api.lua) | Única puerta a la API del juego para hechizos, objetos, macros, cursor y metadatos. Usa la API moderna (`C_Spell`, `C_Item`, `C_SpellBook`); donde hay una equivalente clásica (hechizo conocido, número de objetos, metadatos) la usa como respaldo, y si falta una función de hechizos u objetos devuelve vacío en lugar de dar un error de Lua (las de macros, cursor y jugador se usan directamente) |
| [`Core/Storage.lua`](Core/Storage.lua) | Único módulo que toca la variable guardada `StreamDeckWoWChar` (huecos y posición del botón del minimapa) |
| [`Defaults/Defaults.lua`](Defaults/Defaults.lua) | Registro de valores por defecto: comunes y por clase |
| [`Defaults/Common.lua`](Defaults/Common.lua) | Huecos comunes a todas las clases |
| [`Defaults/Classes/Hunter.lua`](Defaults/Classes/Hunter.lua) | Huecos del cazador |
| [`Core/Slots.lua`](Core/Slots.lua) | Qué hay en cada hueco: definición, resolución, foto para el plugin |
| [`Core/Bindings.lua`](Core/Bindings.lua) | Asigna los atajos y decide cuándo recalcular |
| [`UI/SlotButton.lua`](UI/SlotButton.lua) | Componente de botón de hueco: icono, arrastrar y soltar, tooltip |
| [`UI/ConfigWindow.lua`](UI/ConfigWindow.lua) | La ventana `/sdeck config` |
| [`UI/MinimapButton.lua`](UI/MinimapButton.lua) | El botón del minimapa: abre la ventana, muestra el estado y se puede mover o esconder. Hecho a mano, sin LibDBIcon, para no depender de librerías externas |
| [`Core/Commands.lua`](Core/Commands.lua) | Comandos `/sdeck`; los publica en `ns.Commands.Run` para que el botón del minimapa los reutilice |

### Override bindings

Los atajos se asignan con `SetOverrideBinding*` y no con `SetBinding*`:

- `SetBinding` cambia **tus** atajos guardados (se sincronizan con el servidor) y el cambio se queda aunque desinstales el addon.
- `SetOverrideBinding` crea una capa temporal ligada a un *frame* del addon, con prioridad sobre los atajos normales. No se guarda en ningún sitio y desaparece al desactivar el addon.

Cada recálculo empieza de cero (`ClearOverrideBindings`) y asigna los 12 huecos: es más simple que calcular diferencias y, con 12 huecos, no cuesta nada.

Los hechizos se asignan **por nombre**, no por ID: con el nombre sin rango, WoW lanza siempre el rango más alto que conozcas, así que la tecla sigue valiendo al subir de nivel.

### Mensajes entre módulos

Los módulos no se llaman directamente cuando eso crearía dependencias circulares; se avisan con mensajes internos ([`Core/Util.lua`](Core/Util.lua)):

- `SLOT_CHANGED`: el jugador ha cambiado un hueco → `Bindings` recalcula.
- `SLOTS_UPDATED`: se han asignado los huecos → la ventana se redibuja y, la primera vez, se escribe el resumen en el chat.

### Tipos de entrada de un hueco

| Forma | Ejemplo | Comportamiento |
|---|---|---|
| `spells = { … }` | `{ 18260, 3413, 3102, 2550 }` | El primer hechizo que conozcas (útil para los rangos de las profesiones). Si no conoces ninguno, no se asigna nada |
| `items = { … }` | `{ 13446, 3928, … }` | El primer objeto que lleves en las bolsas, de mejor a peor. Si no llevas ninguno, no se asigna nada |
| `names = { … }` | `{ "Campamento", "Acampar" }` | Hechizos por nombre, cuando aún no se conoce su ID |
| `{ kind = "spell", id = … }` | arrastrado por el jugador | Siempre ese hechizo; no disponible mientras no lo hayas aprendido |
| `{ kind = "item", id = … }` | arrastrado por el jugador | Siempre ese objeto; no disponible mientras no lo lleves |
| `{ kind = "macro", name = … }` | arrastrado por el jugador | Esa macro, guardada por nombre (el índice cambia al borrar otras); si la borras, el atajo queda sin asignar: la tecla de la Stream Deck muestra «F*n*» y `/sdeck` la marca en rojo |

---

## 5. El plugin por dentro

Stream Deck lanza el plugin con su propio Node.js (versión 20, indicada en el [`manifest.json`](StreamDeck/com.fsegado.wowdeck.sdPlugin/manifest.json)) y le pasa por argumentos un puerto local. Todo lo demás es un **WebSocket** con mensajes JSON:

- **Stream Deck → plugin:** `willAppear` (una tecla se muestra), `willDisappear`, `keyDown`, `didReceiveSettings`…
- **Plugin → Stream Deck:** `setImage`, `setTitle`, `showAlert`…

Cada tecla visible tiene un `context`, un identificador opaco con el que se le dirigen los mensajes.

[`bin/plugin.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/plugin.js) solo crea las piezas y las conecta. Las piezas están en `bin/lib/`:

| Archivo | Responsabilidad | ¿Específico de WoW? |
|---|---|---|
| [`constants.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/lib/constants.js) | Rutas, tiempos, códigos de tecla, URLs; lee la versión del `manifest.json` | — |
| [`log.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/lib/log.js) | Registro a archivo y a la salida estándar | No |
| [`streamdeck.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/lib/streamdeck.js) | Conexión con la aplicación de Stream Deck | No |
| [`helper.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/lib/helper.js) | Gestiona el proceso auxiliar de PowerShell | No |
| [`luatable.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/lib/luatable.js) | Lee el formato Lua de las SavedVariables | No |
| [`images.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/lib/images.js) | Imágenes para las teclas (archivos y SVG generados) | No |
| [`text.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/lib/text.js) | Títulos en dos líneas | No |
| [`wow.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/lib/wow.js) | Localiza WoW Forever y sus SavedVariables | Sí |
| [`watcher.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/lib/watcher.js) | Avisa cuando WoW reescribe las SavedVariables | Sí |
| [`icons.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/lib/icons.js) | Iconos de Wowhead con caché en disco | Sí |
| [`slotAction.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/lib/slotAction.js) | La acción «Hueco WoW»: pintar y pulsar | Sí |

### El proceso auxiliar

Node no puede simular teclado sin un módulo nativo compilado para cada versión. En su lugar, el plugin arranca **una vez** un PowerShell ([`helper.ps1`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/helper.ps1)) que compila un poco de C# ([`native/WowDeckKeys.cs`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/native/WowDeckKeys.cs)) y se queda escuchando órdenes por la entrada estándar:

```
(al arrancar)                  →                               escribe "READY"
KEYS 17,18,16,114              → pulsa Ctrl+Alt+Mayús+F3     → responde "OK KEYS"
DIM entrada.jpg|salida.png|144 → guarda el icono en gris     → responde "OK DIM"
(orden desconocida o fallo)    →                               responde "ERR <motivo>"
```

Se comunican en UTF-8, para que las rutas con tildes (`C:\Users\José\…`) funcionen. Arrancarlo cuesta un segundo; después cada orden tarda milisegundos. Si una pulsación falla, la tecla muestra el triángulo de aviso de Stream Deck. Si el proceso muere, las órdenes pendientes se dan por fallidas y el plugin lo relanza un segundo después; si vuelve a caerse sin llegar a arrancar, cada vez espera el doble (hasta un minuto), para no relanzar PowerShell sin parar.

### Cómo pinta cada tecla

| Situación | Imagen | Título |
|---|---|---|
| Todavía no has entrado con el addon | Texto «F*n*» | — |
| Hueco vacío | Fondo liso | — |
| Hechizo u objeto disponible | Icono de Wowhead | Nombre corto |
| Aún no lo tienes (no aprendido, sin pociones), sea un valor por defecto o algo que arrastraste | Icono en gris oscuro (en color si no se pudo oscurecer) | Nombre corto |
| Macro o habilidad sin ID conocido | Texto «Macro» o «F*n*» | Nombre |
| Sin conexión y sin el icono en caché | Texto «F*n*» | Nombre corto |

Las descargas de Wowhead tienen un tiempo límite de 10 segundos, solo se guardan si la respuesta es una imagen, y un icono que falla no se vuelve a pedir hasta pasados 10 minutos (o hasta que el plugin se reinicie: esa espera solo se recuerda mientras está en marcha).

### Cómo se entera de los cambios

Cada 1,5 segundos recorre las carpetas de los personajes en `WTF\Account` y consulta la **fecha de modificación** de cada `StreamDeckWoW.lua`, sin abrirlos. Solo **lee** el más reciente cuando su fecha (o el archivo elegido) cambia, es decir, cuando WoW lo ha reescrito.

Consultar fechas es de lo más barato que hay: incluso con decenas de personajes no llega a un milisegundo por comprobación. Se hace así en lugar de usar los avisos de cambios de Windows (`fs.watch`), que pueden dispararse varias veces o perderse según cómo escriba el archivo el juego (WoW guarda primero una copia `.bak`).

---

## 6. El contrato entre addon y plugin

Addon y plugin comparten los atajos (con el número de huecos) y el formato del archivo de SavedVariables. Si se cambia algo de esto, hay que cambiarlo en todos los sitios donde aparece.

### 6.1. Los atajos

| Sitio | Dónde | Valor |
|---|---|---|
| Addon | `Const.KEY_MODIFIERS` y `Const.KEY_MODIFIERS_LABEL` en [`Core/Constants.lua`](Core/Constants.lua) | `"ALT-CTRL-SHIFT-"` y `"Ctrl+Alt+Mayús+"` |
| Addon | `## Notes` en [`StreamDeckWoW.toc`](StreamDeckWoW.toc) | texto de la descripción |
| Plugin | `MODIFIERS` en [`bin/lib/constants.js`](StreamDeck/com.fsegado.wowdeck.sdPlugin/bin/lib/constants.js) | `[VK.CTRL, VK.MENU, VK.SHIFT]` |
| Plugin | `KEYS` en [`ui/slot.html`](StreamDeck/com.fsegado.wowdeck.sdPlugin/ui/slot.html) | `"Ctrl+Alt+Mayús+F"` |
| Plugin | `Tooltip` en [`manifest.json`](StreamDeck/com.fsegado.wowdeck.sdPlugin/manifest.json) | texto de la ayuda de la acción |

Hueco *n* = tecla F*n*. El número de huecos (12) está en `Const.NUM_SLOTS` del addon, en `NUM_SLOTS` de `bin/lib/constants.js` y en `NUM_SLOTS` de `ui/slot.html`. El panel de ajustes corre aparte del plugin y no puede leer sus constantes, por eso repite estos dos valores. Además, «F1..F12» y «12 huecos» aparecen como texto en el `Tooltip` del `manifest.json` y en la descripción del `.toc`, y el layout del perfil coloca los huecos del 1 al 12.

### 6.2. El archivo de SavedVariables

Ruta (una por personaje):

```
World of Warcraft\_forever_\WTF\Account\<CUENTA>\<Reino>\<Personaje>\SavedVariables\StreamDeckWoW.lua
```

Contenido, tal como lo escribe WoW:

```lua
StreamDeckWoWChar = {
    ["class"] = "HUNTER",
    ["updated"] = 1762200000,          -- última actualización (segundos desde 1970)
    ["custom"] = {                      -- lo que ha cambiado el jugador
        [9] = { ["kind"] = "macro", ["name"] = "Trampa" },
        [11] = false,                   -- vaciado a propósito
    },
    ["slots"] = {                       -- la foto que lee el plugin
        {
            ["active"] = true,          -- ¿se puede usar ahora?
            ["kind"] = "item",          -- "spell" | "item" | "macro"
            ["id"] = 6948,              -- ID para descargar el icono
            ["icon"] = 134414,          -- ID de archivo de icono del juego
            ["name"] = "Piedra de hogar",
            ["short"] = "Hogar",        -- texto de la tecla
        }, -- [1]
        -- ... hasta [12]
    },
    ["minimap"] = {                     -- botón del minimapa (solo para el addon)
        ["angle"] = 225,                -- posición alrededor del minimapa, en grados
        ["hidden"] = true,              -- solo si lo has ocultado con /sdeck minimapa
    },
}
```

Casos de cada hueco en `slots`:

| Caso | Campos |
|---|---|
| Asignado y disponible | `active = true`, `kind`, `id` (no en macros), `icon`, `name`, `short` |
| Asignado pero aún no lo tienes (algo que arrastraste y no has aprendido o no llevas) | Igual, con `active = false` |
| Sin nada asignable (valor por defecto que aún no tienes) | `active = false`, `kind` e `id` de reserva (el más básico de la lista), `name` y `short`; sin `icon`. Con `names = { … }` no hay ni `kind` ni `id` |
| Personalizado que ya no existe (macro borrada, o hechizo arrastrado cuyo ID no tiene nombre) | `active = false` y `name`; sin `kind`, `id`, `icon` ni `short` |
| Vacío | `active = false`, `empty = true` |

Si el cliente todavía no tiene un objeto en caché, el atajo se asigna con `"item:<id>"`, pero en la foto `name` queda vacío (y `short` también, si el hueco no tiene texto propio) hasta que el servidor envía los datos; `/sdeck` lo muestra como «objeto <id> (cargando datos)».

El plugin solo usa `slots` (y `class`, para su registro). `custom` y `minimap` son para el propio addon.

---

## 7. Los atajos de teclado

**¿Por qué `Ctrl+Alt+Mayús+F1…F12`?** Nadie los teclea a mano: los pulsa la Stream Deck. Usar los tres modificadores a la vez da una combinación que prácticamente ningún programa ni el propio juego usan, así que no choca con tus atajos.

**¿Y Alt+F4 en el hueco 4?** Comprobado: con Ctrl pulsado, Windows no trata `Ctrl+Alt+Mayús+F4` como «cerrar ventana».

**¿Y si estoy manteniendo Mayús con la mano?** El auxiliar lo detecta (`GetAsyncKeyState`): no pulsa ni suelta los modificadores que ya mantienes. Si lo hiciera, el juego creería que has soltado tu tecla aunque la sigas pulsando.

**¿Es seguro con las normas de Blizzard?** Cada pulsación de la Stream Deck es una tecla y lanza una sola habilidad, igual que cualquier teclado con teclas macro. Lo que Blizzard sanciona es automatizar (varias acciones por pulsación o jugar sin ti).

---

## 8. El perfil de Stream Deck

El perfil **«WoW Forever»** para Stream Deck + tiene dos páginas de 8 teclas y 4 diales. Es un *smart profile*: está vinculado al `Wow.exe` de WoW Forever, así que Stream Deck lo activa al poner el juego en primer plano y vuelve al perfil predeterminado al salir.

```
Página 1                                   Página 2
┌───────┬───────┬───────┬───────┐          ┌─────────┬──────────┬────────┬────────┐
│ Hueco │ Hueco │ Hueco │ Hueco │          │Mochilas │ Hueco 12 │ Hueco 8│ Hueco 9│
│   1   │   2   │   3   │   4   │          │ (Mayús+B)│          │        │        │
├───────┼───────┼───────┼───────┤          ├─────────┼──────────┼────────┼────────┤
│ Hueco │ Hueco │ Hueco │   ›   │          │ Hueco 10│ Hueco 11 │ Reposo │   ‹    │
│   5   │   6   │   7   │       │          │         │          │  (X)   │        │
└───────┴───────┴───────┴───────┘          └─────────┴──────────┴────────┴────────┘

Diales (iguales en las dos páginas): girar ⟲ / girar ⟳ / pulsar
  Objetivo   enemigo anterior / siguiente / asistir (F)
  Mascota    quieto / seguir / atacar           (barra de mascota del juego)
  Actitud    pasivo / agresivo / defensivo      (barra de mascota del juego)
  Chat/Mapa  subir chat / bajar chat / mapa (M)
```

Las teclas «Hueco» son del plugin. Mochilas, Reposo y los diales son acciones normales de atajos de Stream Deck, con teclas que el juego trae por defecto, así que no pasan por el addon. Las flechas son acciones de cambio de página. Los diales de mascota solo hacen algo con clases que tienen mascota.

El perfil se genera a partir de un *layout* escrito como datos ([`layouts/wow_forever.py`](StreamDeck/profile/layouts/wow_forever.py)). Lo que depende de cada equipo, como el número de serie de la Stream Deck o la ruta de WoW, no está en el repositorio: se detecta al generar el perfil (ver [§14.3](#143-generar-el-perfil-de-stream-deck)).

---

## 9. Requisitos

| Para | Necesitas |
|---|---|
| Jugar | **World of Warcraft: Forever** (cliente 1.60.1 o posterior) |
| La Stream Deck | **Stream Deck +** (el perfil está pensado para sus 8 teclas y 4 diales) y la aplicación **Stream Deck 7.6** o posterior, en **Windows 10/11**. El perfil generado usa el formato de la 7.6; el plugin declara compatibilidad desde la 6.4, pero solo se ha probado en la 7.6 |
| Instalar el plugin desde el código | **npm**, para instalar la única dependencia (`ws`) |
| Generar el perfil o el icono | **Python 3** con **Pillow** (`pip install pillow`) |

El addon funciona por su cuenta sin Stream Deck: cualquier programa o teclado que envíe `Ctrl+Alt+Mayús+F1…F12` sirve.

---

## 10. Instalación

### 10.1. Addon

Clona o copia este repositorio como carpeta `StreamDeckWoW` dentro de los addons de Forever:

```
World of Warcraft\_forever_\Interface\AddOns\StreamDeckWoW\StreamDeckWoW.toc
```

El nombre de la carpeta tiene que coincidir con el del `.toc`. La subcarpeta `StreamDeck/` (plugin y generadores) no molesta: WoW solo carga los archivos que lista el `.toc`.

En la pantalla de personajes, botón **AddOns**, comprueba que **StreamDeck WoW** está activado.

### 10.2. Plugin

1. Instala la dependencia del plugin:

   ```bash
   cd StreamDeck/com.fsegado.wowdeck.sdPlugin/bin
   npm ci --omit=dev
   ```

2. Pon la carpeta `com.fsegado.wowdeck.sdPlugin` en `%APPDATA%\Elgato\StreamDeck\Plugins\`. Para desarrollo es más cómodo un **enlace de directorio**, que no necesita permisos de administrador y mantiene el plugin al día con el repositorio:

   ```bat
   mklink /J "%APPDATA%\Elgato\StreamDeck\Plugins\com.fsegado.wowdeck.sdPlugin" "<ruta al repo>\StreamDeck\com.fsegado.wowdeck.sdPlugin"
   ```

   (`mklink` es un comando de `cmd`.)

3. Reinicia la aplicación de Stream Deck. En la lista de acciones aparecerá la categoría **WoW Forever** con la acción **Hueco WoW**.

El plugin busca WoW Forever solo, por este orden:
1. La variable de entorno `WOWDECK_FOREVER`, si existe (pensada para pruebas).
2. La ruta real del plugin, siguiendo el enlace de directorio: si está dentro de `…\_forever_\Interface\`, esa instalación.
3. `<unidad>:\<carpeta>\World of Warcraft\_forever_`, con las unidades de la C: a la H: y como carpeta `Program Files (x86)`, `Program Files`, `Juegos`, `Games` o la raíz de la unidad.

Solo vale una carpeta que ya tenga `WTF`, es decir, en la que el juego haya arrancado al menos una vez. Si no encuentra ninguna, lo vuelve a intentar cada 10 segundos, así que basta con abrir el juego: no hace falta reiniciar Stream Deck.

### 10.3. Perfil

Puedes montarlo a mano en la aplicación de Stream Deck: arrastra **Hueco WoW** a cada tecla y elige su número en el panel de ajustes (si no eliges ninguno, la tecla usa el hueco 1). O puedes generarlo ya montado ([§14.3](#143-generar-el-perfil-de-stream-deck)).

---

## 11. Uso

### Comandos

| Comando | Qué hace |
|---|---|
| `/sdeck` o `/sdeck estado` | Lista los 12 huecos: qué tiene asignado cada uno y, en rojo, lo que todavía no tienes. En combate muestra lo último asignado y avisa de que se actualizará al terminar |
| `/sdeck config` | Abre o cierra la ventana de configuración (también con clic en el botón del minimapa) |
| `/sdeck minimapa` | Oculta el botón del minimapa o lo vuelve a mostrar; se recuerda por personaje |
| `/sdeck ayuda` | Versión del addon y lista de comandos (también sale con cualquier otro texto) |

### Botón del minimapa

Al entrar aparece un botón con el icono del addon en el borde del minimapa (abajo a la izquierda la primera vez):

- **Clic:** abre o cierra la ventana de configuración.
- **Clic derecho:** el estado de las teclas en el chat, como `/sdeck`.
- **Arrastrar:** lo mueve alrededor del minimapa. La posición se guarda por personaje, como un ángulo, así que se mantiene aunque cambie el tamaño o la escala del minimapa. Si otro addon hace el minimapa cuadrado (y lo anuncia con `GetMinimapShape`), el botón recorre sus lados.
- `/sdeck minimapa` lo esconde si molesta, y el mismo comando lo recupera.

### Ventana de configuración

<p align="center"><code>/sdeck config</code> o clic en el botón del minimapa</p>

- **Arrastra** un hechizo del libro, un objeto de las bolsas o una macro a un hueco. También vale coger con un clic y soltar con otro, como en las barras de acción. Otras cosas (monturas, acciones de mascota…) no se aceptan.
- **Clic derecho:** vuelve al valor por defecto.
- **Mayús + clic derecho:** deja el hueco vacío.
- Nombre en **dorado** = personalizado; en gris claro = valor por defecto; «vacío» en gris oscuro = hueco vacío.
- **Icono en gris** = todavía no lo tienes, tanto si es un valor por defecto como si lo has arrastrado tú.
- **Actualizar Stream Deck** recarga la interfaz para que WoW guarde el archivo y la Stream Deck muestre los iconos nuevos.

Los cambios funcionan en el juego **al momento** (si estás en combate, al terminar la pelea); recargar solo hace falta para que la Stream Deck los vea.

---

## 12. Huecos por defecto

### De dónde sale lo que hace cada tecla

Todo lo que hace cada hueco lo decide **el addon**, dentro del juego: ni el plugin ni el perfil de Stream Deck saben qué hechizo hay detrás de una tecla. Para cada hueco, el addon mira por este orden y se queda con lo primero que encuentra:

1. **Lo que has configurado tú** en `/sdeck config`. Se guarda en tus SavedVariables, por personaje.
2. **El valor por defecto de tu clase**, en [`Defaults/Classes/<Clase>.lua`](Defaults/Classes/Hunter.lua).
3. **El valor por defecto común** a todas las clases, en [`Defaults/Common.lua`](Defaults/Common.lua).
4. Si no hay nada, el hueco queda **vacío**.

Los archivos de `Defaults/` son solo un **punto de partida**: que el addon funcione nada más instalarlo, sin configurar nada. En cuanto arrastras algo a un hueco, lo tuyo tiene prioridad y el valor por defecto de ese hueco deja de usarse. Con clic derecho en la ventana vuelves a él.

**¿Hacen falta los archivos por clase?** No son imprescindibles. Sin `Hunter.lua`, el cazador empezaría solo con los huecos comunes (hogar, pociones y campamento) y el resto vacío, hasta que arrastres tú sus habilidades una vez. Tener un archivo por clase da mejor primera impresión, sobre todo si compartes el addon, a cambio de mantener sus listas de IDs. Una clase sin archivo propio funciona igual, solo que empieza con los huecos comunes.

Los valores por defecto usan **IDs** de hechizos y objetos, no nombres, porque los IDs no cambian con el idioma del cliente. La excepción es el campamento, que se busca por nombre porque aún no se conoce su ID. Con listas como `spells = { … }` o `items = { … }` el addon elige el primero disponible: el rango más alto de una profesión que conozcas o la mejor poción que lleves.

### Valores actuales

| Hueco | Atajo | Todas las clases | Cazador |
|---|---|---|---|
| 1 | Ctrl+Alt+Mayús+F1 | Piedra de hogar | |
| 2 | Ctrl+Alt+Mayús+F2 | | Aspecto del guepardo |
| 3 | Ctrl+Alt+Mayús+F3 | | Llamar a mascota |
| 4 | Ctrl+Alt+Mayús+F4 | | Revivir mascota |
| 5 | Ctrl+Alt+Mayús+F5 | | Alimentar mascota |
| 6 | Ctrl+Alt+Mayús+F6 | La mejor poción de curación que lleves | |
| 7 | Ctrl+Alt+Mayús+F7 | La mejor poción de maná que lleves | |
| 8 | Ctrl+Alt+Mayús+F8 | | Cocina |
| 9 | Ctrl+Alt+Mayús+F9 | | Peletería |
| 10 | Ctrl+Alt+Mayús+F10 | | Buscar hierbas |
| 11 | Ctrl+Alt+Mayús+F11 | | Alquimia |
| 12 | Ctrl+Alt+Mayús+F12 | Campamento (sistema de acampada de Forever) | |

Los valores de una clase tienen prioridad sobre los comunes con el mismo número. Lo que configures en el juego tiene prioridad sobre todo.

---

## 13. Estructura del proyecto

```
StreamDeckWoW/                         ← carpeta del addon (raíz del repositorio)
├── StreamDeckWoW.toc                  manifiesto del addon: metadatos y orden de carga
├── Core/                              núcleo del addon
│   ├── Constants.lua                  valores fijos
│   ├── Util.lua                       utilidades genéricas
│   ├── Keys.lua                       atajos de cada hueco
│   ├── Api.lua                        acceso a la API del juego
│   ├── Storage.lua                    SavedVariables
│   ├── Slots.lua                      lógica de los huecos
│   ├── Bindings.lua                   asignación de atajos
│   └── Commands.lua                   comandos /sdeck
├── Defaults/                          valores por defecto (solo datos)
│   ├── Defaults.lua                   registro
│   ├── Common.lua                     todas las clases
│   └── Classes/Hunter.lua             cazador
├── UI/                                interfaz
│   ├── SlotButton.lua                 botón de hueco
│   ├── ConfigWindow.lua               ventana /sdeck config
│   └── MinimapButton.lua              botón del minimapa
├── Media/Icon.tga                     icono del addon (lista de addons y chat)
└── StreamDeck/                        todo lo de Stream Deck (WoW no lo carga)
    ├── com.fsegado.wowdeck.sdPlugin/  el plugin
    │   ├── manifest.json              manifiesto: nombre, versión, acción, Node
    │   ├── bin/plugin.js              punto de entrada
    │   ├── bin/lib/*.js               piezas del plugin (ver §5)
    │   ├── bin/helper.ps1             proceso auxiliar: teclas e imágenes
    │   ├── bin/native/WowDeckKeys.cs  pulsaciones de teclado (C#)
    │   ├── bin/package.json           dependencia del plugin (ws) para npm
    │   ├── bin/package-lock.json      versiones exactas, para "npm ci"
    │   ├── ui/slot.html               panel de ajustes de la tecla
    │   └── imgs/                      iconos del plugin
    ├── profile/                       generador del perfil de Stream Deck
    │   ├── make_profile.py            punto de entrada
    │   ├── layouts/                   un perfil por archivo, como datos (wow_forever.py)
    │   ├── lib/*.py                   formato de perfiles, acciones, imágenes, descarga de iconos…
    │   ├── local.example.json         plantilla de configuración del equipo
    │   └── icons/                     iconos de Wowhead descargados (no se sube al repositorio)
    └── branding/                      generador del icono del proyecto
        ├── make_icons.py
        ├── draw.py
        └── constants.py               colores y medidas
```

---

## 14. Desarrollo

### 14.1. Añadir una clase

1. Crea `Defaults/Classes/<Clase>.lua` siguiendo el modelo de [`Hunter.lua`](Defaults/Classes/Hunter.lua):

   ```lua
   local _, ns = ...

   ns.Defaults.RegisterClass("WARRIOR", {
       [2] = { short = "Grito", spells = { 6673 } },
       -- ...
   })
   ```

   La clave es el nombre interno de la clase en inglés: `WARRIOR`, `PALADIN`, `HUNTER`, `ROGUE`, `PRIEST`, `SHAMAN`, `MAGE`, `WARLOCK`, `DRUID`.

2. Añade la línea `Defaults\Classes\<Clase>.lua` al `.toc`, junto a la del cazador.

Los IDs de hechizos y objetos de Forever se consultan en [Wowhead (Forever)](https://www.wowhead.com/forever). Para las profesiones, lista todos los rangos del más alto al más bajo.

### 14.2. Cambiar los atajos

Cambia **todos** los sitios del contrato ([§6.1](#61-los-atajos)):
- en el addon, `Const.KEY_MODIFIERS` y `Const.KEY_MODIFIERS_LABEL`, y la descripción del `.toc`;
- en el plugin, `MODIFIERS` en `bin/lib/constants.js`, `KEYS` en `ui/slot.html` y el `Tooltip` del `manifest.json`.

### 14.3. Generar el perfil de Stream Deck

Con la aplicación de Stream Deck **cerrada** (si está abierta, sobrescribe los cambios al salir):

```bash
python StreamDeck/profile/make_profile.py wow_forever "%APPDATA%\Elgato\StreamDeck\ProfilesV3"
```

Opciones:
- `--uuid <UUID>` reemplaza un perfil existente: **lo sustituye entero**, incluidos los cambios que hayas hecho a mano en la aplicación. El nuevo se escribe primero en una carpeta temporal y el antiguo solo se borra si todo ha ido bien, así que un fallo a medias no te deja sin perfil.
- `--icons <carpeta>` indica la carpeta de los iconos de WoW (por defecto, `StreamDeck/profile/icons/`).
- `--local <archivo>` indica la configuración del equipo (por defecto, `StreamDeck/profile/local.json`, si existe).

Qué hace:
- El **dispositivo** lo detecta a partir de los perfiles que ya tienes en `%APPDATA%\Elgato\StreamDeck\ProfilesV3`, aunque el destino sea otra carpeta. Hace falta al menos un perfil de la Stream Deck +. La **ruta de WoW** la busca en las rutas de instalación habituales.
- Si la detección falla, copia [`local.example.json`](StreamDeck/profile/local.example.json) como `local.json` y **deja solo los campos que necesites**: cualquier campo presente sustituye a la detección. `local.json` no se sube al repositorio.
- Escribe el formato **ProfilesV3** (Stream Deck 7.6 o posterior), con las páginas del layout y una página «por defecto» vacía que exige la aplicación.
- Los iconos de WoW de las teclas fijas no están en el repositorio, porque son arte de Blizzard: **los que falten se descargan solos** de Wowhead la primera vez. Solo se guardan si la respuesta es de verdad una imagen. Los de los huecos no hacen falta: el plugin los descarga solo.

Para crear otro perfil, añade un archivo en `layouts/` con el vocabulario de [`lib/spec.py`](StreamDeck/profile/lib/spec.py):
- **Teclas y diales:** `slot(n)`, `hotkey(título, imagen, [atajos])`, `next_page()`, `prev_page()`, `switch_profile(título, imagen, "Nombre del perfil")` y `dial(título, imagen, izquierda, derecha, pulsar)`.
- **Imágenes:** `wow("nombre_del_icono")`, `rest()` (luna) y `home()` (casa).
- **Atajos:** `key("B", shift=True)` y similares, de [`lib/keys.py`](StreamDeck/profile/lib/keys.py). Solo admite las teclas definidas en `VK` de [`lib/constants.py`](StreamDeck/profile/lib/constants.py); para usar otra, añádela allí.

### 14.4. Regenerar el icono

Los colores y medidas están en [`branding/constants.py`](StreamDeck/branding/constants.py). Para generar todos los tamaños (addon y plugin) y una lámina de revisión:

```bash
python StreamDeck/branding/make_icons.py --preview revision.png
```

### 14.5. Versión

Cada pieza tiene un único sitio donde se escribe su versión; el resto del código la lee de ahí:

| Pieza | Dónde |
|---|---|
| Addon | `## Version` en [`StreamDeckWoW.toc`](StreamDeckWoW.toc) (`0.1.0`) |
| Plugin | `Version` en [`manifest.json`](StreamDeck/com.fsegado.wowdeck.sdPlugin/manifest.json) (`0.1.0.0`: Stream Deck usa cuatro cifras) |

`bin/package.json` no lleva versión a propósito: es un paquete privado que no se publica en npm, y así no hay una tercera copia que mantener.

`## Interface: 16001` en el `.toc` es la versión de interfaz de WoW Forever 1.60.1. Si una actualización del juego la cambia, el addon aparecerá como incompatible; el valor nuevo se obtiene en el juego con `/dump select(4, GetBuildInfo())`.

---

## 15. Diagnóstico y solución de problemas

### Dónde mirar

| Qué | Dónde |
|---|---|
| Estado de las teclas en el juego | `/sdeck` |
| Errores de Lua | Actívalos con `/console scriptErrors 1` |
| Registro del plugin | `%APPDATA%\WoWDeck\plugin.log` (al pasar de 1 MB se aparta como `plugin.log.old` y empieza uno nuevo) |
| Registro del plugin según Stream Deck | `%APPDATA%\Elgato\StreamDeck\logs\com.fsegado.wowdeck0.log` |
| Caché de iconos | `%APPDATA%\WoWDeck\icons\` (imágenes, también las versiones en gris `*_dim.png`) y `%APPDATA%\WoWDeck\icon-names.json` (qué icono corresponde a cada hechizo u objeto). Se pueden borrar sin problema: se vuelven a descargar |
| Datos que lee el plugin | `WTF\Account\...\SavedVariables\StreamDeckWoW.lua` |

### Problemas habituales

**Una tecla de la Stream Deck no hace nada en el juego.**
Mira `/sdeck`: si ese hueco sale en rojo, todavía no tienes lo que tiene asignado. Si sale bien, comprueba que el foco está en la ventana de WoW y que no estás escribiendo en el chat.

**Las teclas de la Stream Deck muestran «F1», «F2»…**
- **Sin título:** el plugin aún no ha encontrado datos. Entra con un personaje con el addon activado y haz `/reload` (o sal del juego) para que WoW escriba el archivo. Si sigue igual, mira `plugin.log`: si dice «no encuentro la carpeta _forever_ de WoW», abre el juego una vez (el plugin lo reintenta solo) o comprueba que tu instalación está en una de las rutas que busca ([§10.2](#102-plugin)).
- **Con título:** hay datos, pero no se pudo descargar el icono de Wowhead (sin conexión, o Wowhead no conoce ese ID). Se reintenta pasados 10 minutos.

**He cambiado un hueco y la Stream Deck no lo refleja.**
WoW solo escribe el archivo al recargar, cerrar sesión o salir. Pulsa **Actualizar Stream Deck** en la ventana o escribe `/reload`.

**He cambiado de personaje y la Stream Deck muestra las teclas del anterior.**
Es lo esperado: el archivo del personaje nuevo no se guarda hasta que recargas o sales ([§3.5](#35-con-varios-personajes)). Haz un `/reload`.

**Ninguna tecla funciona, ni las de atajos normales.**
Si WoW (o Battle.net) se ejecuta **como administrador**, Windows bloquea las pulsaciones que llegan de programas sin esos permisos. No marques WoW para ejecutarse como administrador.

**«Campamento» sale en rojo aunque tengo la habilidad.**
Su nombre exacto en el cliente puede no coincidir con los que prueba el addon. Arrástrala al hueco 12 desde el libro de hechizos con `/sdeck config`.

**El perfil no cambia solo al entrar o salir de WoW.**
Stream Deck activa el perfil cuando la ventana del juego coge el foco, y vuelve al perfil marcado como **predeterminado** en la aplicación cuando otra ventana lo coge. Asegúrate de tener un perfil predeterminado y de usar Stream Deck 7.6 o posterior.

---

## 16. Limitaciones conocidas

- **La Stream Deck se actualiza al recargar**, no en tiempo real: no puede mostrar enfriamientos, cargas ni si la mascota está fuera. El único canal del juego hacia fuera es el archivo de SavedVariables, que WoW escribe al recargar, cerrar sesión o salir (no al entrar: tras cambiar de personaje hace falta un `/reload` para ver sus teclas).
- **En combate no se reasignan atajos** (lo impide el juego): los cambios esperan al final del combate.
- **Solo Windows.** El envío de teclas usa la API de Windows.
- **El perfil está pensado para la Stream Deck +.** El plugin y el addon funcionan con cualquier modelo, pero las páginas y los diales del perfil generado son los de la Stream Deck +.
- **Las teclas fijas del perfil** (Mochilas, Reposo, flechas y diales) usan la acción de atajos de Stream Deck, que no comprueba los modificadores que tengas pulsados con la mano.
