"""
Genera el icono del proyecto en todos los tamaños y formatos.

Uso:
    python make_icons.py [--preview archivo.png]

Escribe los archivos listados en constants.OUTPUTS (addon y plugin). Con
--preview guarda además una lámina con todos los tamaños para revisarlos.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image  # noqa: E402

from constants import OUTPUTS  # noqa: E402
from draw import icon, mono_icon, resized  # noqa: E402


def save(im, path):
    # Para el .tga del addon: Pillow lo guarda sin comprimir y en RGBA (32 bits),
    # que es lo que lee WoW; las medidas tienen que ser potencia de 2 (64).
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path)


def preview(images, path):
    """Lámina con todas las versiones sobre fondo claro y oscuro."""
    pad = 12
    width = sum(im.width for im in images) + pad * (len(images) + 1)
    height = max(im.height for im in images) * 2 + pad * 3
    sheet = Image.new("RGBA", (width, height), (235, 235, 235, 255))
    sheet.paste((40, 40, 46, 255), (0, height // 2, width, height))
    x = pad
    for im in images:
        sheet.alpha_composite(im, (x, pad))
        sheet.alpha_composite(im, (x, height // 2 + pad))
        x += im.width + pad
    sheet.save(path)


def main():
    p = argparse.ArgumentParser(description="Genera el icono del proyecto.")
    p.add_argument("--preview", help="guardar una lámina de revisión en esta ruta")
    args = p.parse_args()

    masters = {"color": icon(), "mono": mono_icon()}
    written = []
    for path, size, kind in OUTPUTS:
        im = resized(masters[kind], size)
        save(im, path)
        written.append(im)
        print(f"{size:>4}px  {kind:<5}  {path}")
    if args.preview:
        # De mayor a menor, para revisar primero el detalle y después cómo
        # aguanta cada tamaño pequeño.
        preview(sorted(written, key=lambda im: -im.width), args.preview)


if __name__ == "__main__":
    main()
