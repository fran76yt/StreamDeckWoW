"""
Acciones del perfil en el formato JSON de Stream Deck.

Cada función devuelve el diccionario de una acción tal como lo guarda la
aplicación en el manifest.json de la página.
"""
from .constants import (HOTKEY_PLUGIN, PAGES_PLUGIN, PROFILE_PLUGIN, WOWDECK_PLUGIN, WOWDECK_SLOT_ACTION,
                        TITLE_STYLE, KEY_FONT_SIZE)
from .keys import pad
from .naming import new_uuid


def state(title=None, image=None, font_size=KEY_FONT_SIZE):
    """Aspecto de la acción: título abajo en blanco con contorno, e imagen opcional."""
    s = dict(TITLE_STYLE, FontSize=font_size)
    if title is not None:
        s["Title"] = title
    if image is not None:
        s["Image"] = "Images/" + image
    return s


def _action(name, plugin, uuid, settings, st):
    return {"ActionID": new_uuid(), "LinkedTitle": True, "Name": name, "Plugin": plugin,
            "Settings": settings, "State": 0, "States": [st], "UUID": uuid}


def hotkey_action(title, image, hotkeys, font_size=KEY_FONT_SIZE):
    """Acción "Activate a Key Command" de Elgato."""
    return _action("Hotkey", HOTKEY_PLUGIN, HOTKEY_PLUGIN["UUID"],
                   {"Coalesce": True, "Hotkeys": pad(hotkeys)}, state(title, image, font_size))


def page_action(direction, image):
    """Cambio a la página siguiente ("next") o anterior ("prev")."""
    suffix = "next" if direction == "next" else "previous"
    name = "Next Page" if direction == "next" else "Previous Page"
    return _action(name, PAGES_PLUGIN, PAGES_PLUGIN["UUID"] + "." + suffix, {}, state("", image))


def switch_profile_action(title, image, profile_uuid):
    """Cambio a otro perfil del mismo dispositivo.

    DeviceUUID vacío = este mismo dispositivo. PageIndex es la página del
    perfil de destino que se abre, contando desde 1.
    """
    settings = {"DeviceUUID": "", "PageIndex": 1, "ProfileUUID": profile_uuid.lower()}
    return _action("Switch Profile", PROFILE_PLUGIN, PROFILE_PLUGIN["UUID"], settings, state(title, image))


def slot_action(n):
    """Tecla "Hueco WoW" del plugin, ligada al hueco n del addon.

    No lleva imagen ni título: los pone el plugin según lo que haya en el hueco
    dentro del juego. Dejarlos en blanco evita que una imagen o un título fijos
    del perfil compitan con los que envía el plugin.
    """
    return _action("Hueco WoW", WOWDECK_PLUGIN, WOWDECK_SLOT_ACTION, {"slot": n}, state())
