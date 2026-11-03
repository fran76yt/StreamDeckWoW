"""
Datos del equipo donde se genera el perfil.

Lo que depende de cada usuario (qué Stream Deck tiene y dónde está instalado
WoW) no va en el código ni en el repositorio. Se obtiene, por orden:

  1. local.json junto a make_profile.py, si existe (no se sube al repositorio;
     ver local.example.json).
  2. Detección automática:
       - el dispositivo, de los perfiles que ya tiene la aplicación de Stream
         Deck para ese modelo;
       - los perfiles a los que saltan las teclas de cambio de perfil, por su
         nombre (su UUID es distinto en cada instalación);
       - WoW, buscando en las rutas de instalación habituales (las mismas que
         usa el plugin).
"""
import glob
import json
import os

from .constants import STREAMDECK_PROFILES_DIR, WOW_DRIVES, WOW_INSTALL_BASES


def load_local_config(path):
    """Contenido de local.json, o {} si no existe."""
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def installed_profiles(profiles_dir=STREAMDECK_PROFILES_DIR):
    """Perfiles instalados: lista de (UUID del perfil, manifiesto raíz)."""
    found = []
    for manifest in glob.glob(os.path.join(profiles_dir, "*.sdProfile", "manifest.json")):
        try:
            with open(manifest, encoding="utf-8") as fh:
                data = json.load(fh)
        except (OSError, ValueError):
            continue
        profile_uuid = os.path.basename(os.path.dirname(manifest)).split(".")[0]
        found.append((profile_uuid, data))
    return found


def detect_device(model):
    """Dispositivo ({"Model", "UUID"}) de un perfil existente de ese modelo."""
    for _, data in installed_profiles():
        device = data.get("Device", {})
        if device.get("Model") == model and device.get("UUID"):
            return {"Model": model, "UUID": device["UUID"]}
    return None


def find_profile_uuid(name, model):
    """UUID del perfil con ese nombre en un dispositivo de ese modelo, o None."""
    for profile_uuid, data in installed_profiles():
        if data.get("Name") == name and data.get("Device", {}).get("Model") == model:
            return profile_uuid
    return None


def find_wow_exe(flavor_dir, exe="Wow.exe"):
    """Ruta del ejecutable de una versión de WoW (p. ej. "_forever_"), o None."""
    for drive in WOW_DRIVES:
        for base in WOW_INSTALL_BASES:
            path = os.path.join(f"{drive}:\\", base, "World of Warcraft", flavor_dir, exe)
            if os.path.exists(path):
                return path
    return None


def resolve_profile_keys(pages, model, overrides):
    """Copia de las páginas con el UUID de destino en cada tecla de cambio de perfil.

    overrides: {"Nombre del perfil": "UUID"} de local.json, por si el nombre no
    coincide o hay varios perfiles con el mismo.
    """
    resolved = []
    for keys in pages:
        page = []
        for key in keys:
            if key and key["type"] == "switch_profile":
                name = key["profile"]
                profile_uuid = overrides.get(name) or find_profile_uuid(name, model)
                if not profile_uuid:
                    raise SystemExit(f'No encuentro el perfil "{name}" en la Stream Deck: créalo o '
                                     f'indica su UUID en local.json ("profiles").')
                key = dict(key, profile_uuid=profile_uuid)
            page.append(key)
        resolved.append(page)
    return resolved


def resolve(layout, local):
    """Layout completo: añade dispositivo, aplicación y perfiles de destino,
    desde local.json o detectándolos.

    Lanza un error claro si algo no se puede averiguar, en lugar de generar un
    perfil que la aplicación no sabría a qué dispositivo asignar.
    """
    model = layout["device_model"]
    device = local.get("device") or detect_device(model)
    if not device:
        raise SystemExit(f'No encuentro una Stream Deck modelo {model}: '
                         'crea un perfil cualquiera en la aplicación o indícala en local.json.')
    app = local.get("wow_exe") or find_wow_exe(layout["wow_flavor"])
    if not app:
        raise SystemExit(f'No encuentro WoW ({layout["wow_flavor"]}): indica "wow_exe" en local.json.')
    pages = resolve_profile_keys(layout["pages"], model, local.get("profiles", {}))
    return dict(layout, device=device, app=app, pages=pages)
