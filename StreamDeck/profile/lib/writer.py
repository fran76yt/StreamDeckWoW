"""
Escritura de un perfil de Stream Deck a disco.

Formato (ProfilesV3, Stream Deck 7.6 o posterior):
    <UUID>.sdProfile/
        manifest.json               nombre, dispositivo, páginas, app asociada
        Images/                     imágenes del perfil (vacía en los nuestros)
        Profiles/
            <UUID DE LA PÁGINA>/
                manifest.json       acciones de teclas y diales de esa página
                Images/*.png        imágenes de las teclas

La carpeta destino suele ser %APPDATA%\\Elgato\\StreamDeck\\ProfilesV3, con la
aplicación cerrada: si está abierta, sobrescribe los cambios al salir.
"""
import json
import os
import shutil

from . import actions, images
from .constants import KEY_COLUMNS, DIAL_FONT_SIZE, PROFILE_VERSION
from .naming import page_folder, image_name, new_uuid


def write_json(path, data):
    # UTF-8 sin BOM y sin espacios, igual que los guarda la propia aplicación.
    with open(path, "w", encoding="utf-8", newline="") as fh:
        json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))


def position(index, columns=KEY_COLUMNS):
    """Posición "columna,fila" de la tecla número index (0, 1, 2...) por filas."""
    return f"{index % columns},{index // columns}"


class PageWriter:
    """Construye una página: acumula acciones e imágenes y las escribe."""

    def __init__(self, icons_dir):
        self.icons_dir = icons_dir
        self.images = {}   # nombre de archivo -> imagen de Pillow

    def add_image(self, spec):
        name = image_name()
        self.images[name] = images.render(spec, self.icons_dir)
        return name

    # Una función por tipo de tecla del layout (ver spec.py).
    def build_key(self, key):
        builders = {
            "slot": lambda k: actions.slot_action(k["slot"]),
            "hotkey": lambda k: actions.hotkey_action(k["title"], self.add_image(k["image"]), k["keys"]),
            "page": lambda k: actions.page_action(k["direction"], self.add_image(("arrow", k["direction"]))),
            # profile_uuid lo rellena lib/machine.py a partir del nombre del perfil.
            "switch_profile": lambda k: actions.switch_profile_action(k["title"], self.add_image(k["image"]), k["profile_uuid"]),
        }
        return builders[key["type"]](key)

    def build_dial(self, dial):
        return actions.hotkey_action(dial["title"], self.add_image(dial["image"]), dial["keys"], DIAL_FONT_SIZE)

    def manifest(self, keys, dials):
        keypad = {position(i): self.build_key(k) for i, k in enumerate(keys) if k}
        encoder = {position(i, len(dials)): self.build_dial(d) for i, d in enumerate(dials)}
        return {"Controllers": [{"Actions": keypad or None, "Type": "Keypad"},
                                {"Actions": encoder or None, "Type": "Encoder"}],
                "Icon": "", "Name": ""}

    def write(self, profile_dir, page_uuid, keys, dials):
        d = os.path.join(profile_dir, "Profiles", page_folder(page_uuid))
        os.makedirs(os.path.join(d, "Images"), exist_ok=True)
        manifest = self.manifest(keys, dials)
        # Las imágenes no se comparten entre páginas: cada una lleva su copia.
        for name, im in self.images.items():
            im.save(os.path.join(d, "Images", name))
        write_json(os.path.join(d, "manifest.json"), manifest)


def _remove(path):
    if os.path.isdir(path):
        shutil.rmtree(path)


def write_profile(layout, out_root, icons_dir, profile_uuid=None):
    """Escribe el perfil descrito por layout y devuelve su carpeta.

    Reutilizar profile_uuid reemplaza un perfil existente en lugar de crear otro.
    El perfil nuevo se escribe primero en una carpeta temporal al lado; solo si
    todo ha ido bien se borra el antiguo y se pone el nuevo en su lugar. Así un
    fallo a medias (un icono que no se puede abrir, por ejemplo) no deja al
    usuario sin su perfil. Se sustituye entero porque las páginas reciben UUID
    nuevos en cada generación: escribir encima dejaría las antiguas huérfanas.
    """
    if not layout["pages"]:
        raise SystemExit("El layout no tiene páginas: un perfil necesita al menos una.")
    profile_uuid = (profile_uuid or new_uuid()).upper()
    final_dir = os.path.join(out_root, profile_uuid + ".sdProfile")
    temp_dir = final_dir + ".tmp"
    _remove(temp_dir)   # restos de una ejecución anterior que falló
    try:
        _write_profile_files(layout, temp_dir, icons_dir)
    except BaseException:
        _remove(temp_dir)
        raise
    _remove(final_dir)
    os.replace(temp_dir, final_dir)
    return final_dir


def _write_profile_files(layout, profile_dir, icons_dir):
    """Escribe todos los archivos del perfil en profile_dir."""
    os.makedirs(os.path.join(profile_dir, "Images"), exist_ok=True)
    page_uuids = [new_uuid() for _ in layout["pages"]]
    default_page = new_uuid()   # página "por defecto" vacía que exige la aplicación

    for page_uuid, keys in zip(page_uuids, layout["pages"]):
        PageWriter(icons_dir).write(profile_dir, page_uuid, keys, layout.get("dials", []))
    PageWriter(icons_dir).write(profile_dir, default_page, [], [])

    # "Current" es la página que se muestra al abrir el perfil y "Pages" el
    # orden en que se recorren con las flechas. AppIdentifier lo convierte en
    # "smart profile": se activa solo cuando esa aplicación tiene el foco.
    write_json(os.path.join(profile_dir, "manifest.json"), {
        "AppIdentifier": layout["app"], "Device": layout["device"], "Name": layout["name"],
        "Pages": {"Current": page_uuids[0], "Default": default_page, "Pages": page_uuids},
        "Version": PROFILE_VERSION,
    })
