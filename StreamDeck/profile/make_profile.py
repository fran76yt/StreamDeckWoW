"""
Genera un perfil de Stream Deck a partir de un layout.

Uso:
    python make_profile.py <layout> <carpeta_destino> [--uuid UUID] [--icons CARPETA]

    layout            nombre de un módulo de layouts/ (p. ej. "wow_forever")
    carpeta_destino   normalmente %APPDATA%\\Elgato\\StreamDeck\\ProfilesV2, con
                      la aplicación de Stream Deck cerrada
    --uuid            UUID de un perfil existente para reemplazarlo
    --icons           carpeta con los iconos .jpg de Wowhead (por defecto ./icons)
    --local           configuración del equipo (por defecto ./local.json, opcional)

El dispositivo y la ruta de WoW no están en el código: se detectan en cada
equipo o se leen de local.json (ver lib/machine.py y local.example.json).

Estructura:
    lib/constants.py  valores fijos del formato
    lib/machine.py    datos del equipo (dispositivo, ruta de WoW)
    lib/naming.py     nombres de carpetas e imágenes
    lib/keys.py       atajos de teclado
    lib/images.py     imágenes de las teclas
    lib/actions.py    acciones en formato JSON de Stream Deck
    lib/spec.py       vocabulario para escribir layouts
    lib/writer.py     escritura del perfil a disco
    layouts/*.py      un perfil por archivo, solo datos
"""
import argparse
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)   # para importar lib/ y layouts/ se ejecute desde donde se ejecute

from lib import machine  # noqa: E402
from lib.writer import write_profile  # noqa: E402


def parse_args():
    p = argparse.ArgumentParser(description="Genera un perfil de Stream Deck a partir de un layout.")
    p.add_argument("layout", help='módulo de layouts/, p. ej. "wow_forever"')
    p.add_argument("out_root", help="carpeta ProfilesV2 (o una de prueba)")
    p.add_argument("--uuid", help="UUID de un perfil existente para reemplazarlo")
    p.add_argument("--icons", default=os.path.join(HERE, "icons"), help="carpeta de iconos .jpg")
    p.add_argument("--local", default=os.path.join(HERE, "local.json"), help="configuración del equipo (opcional)")
    return p.parse_args()


def main():
    args = parse_args()
    layout = importlib.import_module(f"layouts.{args.layout}").LAYOUT
    layout = machine.resolve(layout, machine.load_local_config(args.local))
    print(write_profile(layout, args.out_root, args.icons, args.uuid))


if __name__ == "__main__":
    main()
