"""
Vocabulario para describir un layout como datos.

Cada función devuelve un diccionario que describe una tecla o un dial; el
escritor (writer.py) lo convierte en la acción del perfil. Los layouts
(carpeta layouts/) solo usan estas funciones.
"""


def slot(n):
    """Tecla del plugin WoW Deck ligada al hueco n del addon."""
    return {"type": "slot", "slot": n}


def hotkey(title, image, keys):
    """Tecla con atajo fijo. image: descripción de imagen (ver images.py)."""
    return {"type": "hotkey", "title": title, "image": image, "keys": keys}


def next_page():
    return {"type": "page", "direction": "next"}


def prev_page():
    return {"type": "page", "direction": "prev"}


def switch_profile(title, image, profile):
    """Tecla que cambia a otro perfil, indicado por su nombre ("General").

    El nombre se traduce al UUID del perfil en cada equipo (lib/machine.py):
    los UUID son distintos en cada instalación de Stream Deck.
    """
    return {"type": "switch_profile", "title": title, "image": image, "profile": profile}


def dial(title, image, left, right, press):
    """Dial: atajos al girar a la izquierda, a la derecha y al pulsar."""
    return {"type": "dial", "title": title, "image": image, "keys": [left, right, press]}


def wow(icon):
    """Imagen: icono de WoW por su nombre en Wowhead."""
    return ("wow", icon)


def rest():
    """Imagen: luna de la tecla Reposo."""
    return ("rest",)


def home():
    """Imagen: casa (volver al perfil principal)."""
    return ("home",)
