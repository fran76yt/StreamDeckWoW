"""
Perfil "WoW Forever" para una Stream Deck +, común a todas las clases.

Solo datos. Las teclas se listan por filas (4 por fila, 2 filas por página).
Los huecos (slot) los pinta el plugin según lo configurado en el juego para
el personaje con el que se ha entrado; el resto son atajos fijos del propio WoW.
Los diales de mascota usan la barra de mascota del juego, así que solo hacen
algo con clases que tienen mascota (cazador, brujo).
"""
from lib.keys import key
from lib.spec import slot, hotkey, next_page, prev_page, dial, wow, rest

LAYOUT = {
    # Un solo perfil para todas las clases: el plugin pinta los huecos según
    # el personaje con el que se haya entrado por última vez.
    "name": "WoW Forever",

    # "Smart profile": se activa cuando el Wow.exe de esta versión del juego
    # tiene el foco. La ruta completa se busca en cada equipo (lib/machine.py);
    # así no se confunde con el Wow.exe del WoW normal.
    "wow_flavor": "_forever_",

    # Modelo de Stream Deck (+). El dispositivo concreto (su número de serie)
    # se detecta en cada equipo o se indica en local.json.
    "device_model": "20GBD9901",

    "pages": [
        # Página 1: huecos 1-7 del addon
        [slot(1), slot(2), slot(3), slot(4),
         slot(5), slot(6), slot(7), next_page()],

        # Página 2: huecos 8-12. Mochilas y Reposo usan atajos que el juego trae
        # por defecto. Al salir del juego Stream Deck vuelve solo al perfil
        # predeterminado (el marcado como tal en la aplicación).
        [hotkey("Mochilas", wow("inv_misc_bag_08"), [key("B", shift=True)]), slot(12), slot(8), slot(9),
         slot(10), slot(11), hotkey("Reposo", rest(), [key("X")]), prev_page()],
    ],

    # Diales, iguales en todas las páginas: girar izquierda, girar derecha, pulsar.
    # Los de mascota usan las teclas por defecto de la barra de mascota (Ctrl+1..0).
    "dials": [
        dial("Objetivo", wow("ability_hunter_snipershot"),
             key("TAB", shift=True), key("TAB"), key("F")),                      # anterior / siguiente / asistir
        dial("Mascota", wow("ability_hunter_pet_wolf"),
             key("3", ctrl=True), key("2", ctrl=True), key("1", ctrl=True)),     # quieto / seguir / atacar
        dial("Actitud", wow("ability_hunter_beastmastery"),
             key("0", ctrl=True), key("8", ctrl=True), key("9", ctrl=True)),     # pasivo / agresivo / defensivo
        dial("Chat/Mapa", wow("inv_misc_map02"),
             key("PAGE_UP"), key("PAGE_DOWN"), key("M")),                        # subir / bajar / mapa
    ],
}
