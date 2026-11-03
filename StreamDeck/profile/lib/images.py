"""
Imágenes de las teclas.

Una imagen se describe en el layout con una tupla ("tipo", argumentos...) y
render() la convierte en una imagen de Pillow. Así los layouts son solo datos.
"""
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from .constants import (IMAGE_SIZE, REST_BACKGROUND, REST_FOREGROUND,
                        ARROW_BACKGROUND, ARROW_FOREGROUND, FONTS)


def _font(size):
    # Fuentes de Windows en negrita, con respaldo por si no están instaladas.
    for name in FONTS:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def wow_icon(icons_dir, name):
    """Icono de WoW (56x56, descargado de Wowhead) ampliado al tamaño de tecla."""
    im = Image.open(os.path.join(icons_dir, name + ".jpg")).convert("RGB")
    w, h = im.size
    im = im.crop((2, 2, w - 2, h - 2))           # quita el borde negro del icono
    # Lanczos para ampliar y un poco de enfoque para compensar el desenfoque
    # de ampliar 2,5 veces.
    im = im.resize((IMAGE_SIZE, IMAGE_SIZE), Image.LANCZOS)
    return im.filter(ImageFilter.UnsharpMask(1.2, 60, 2))


def rest_icon():
    """Luna con una "z" (tecla Reposo)."""
    im = Image.new("RGB", (IMAGE_SIZE, IMAGE_SIZE), REST_BACKGROUND)
    d = ImageDraw.Draw(im)
    # Luna creciente: un círculo claro tapado en parte por otro del color del fondo.
    d.ellipse((34, 40, 110, 116), fill=REST_FOREGROUND)
    d.ellipse((52, 30, 126, 104), fill=REST_BACKGROUND)
    d.text((88, 34), "z", font=_font(30), fill=REST_FOREGROUND)
    return im


def home_icon():
    """Casa (volver al perfil principal)."""
    im = Image.new("RGB", (IMAGE_SIZE, IMAGE_SIZE), REST_BACKGROUND)
    d = ImageDraw.Draw(im)
    d.polygon([(72, 30), (28, 70), (116, 70)], fill=REST_FOREGROUND)          # tejado
    d.rectangle((40, 68, 104, 112), fill=REST_FOREGROUND)                     # fachada
    d.rounded_rectangle((63, 84, 81, 112), 4, fill=REST_BACKGROUND)          # puerta
    d.rectangle((92, 38, 102, 58), fill=REST_FOREGROUND)                      # chimenea
    return im


def arrow_icon(direction):
    """Flecha de cambio de página ("next" o "prev")."""
    im = Image.new("RGB", (IMAGE_SIZE, IMAGE_SIZE), ARROW_BACKGROUND)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((44, 44, 100, 100), 10, fill=ARROW_FOREGROUND)
    pts = [(64, 56), (84, 72), (64, 88)] if direction == "next" else [(80, 56), (60, 72), (80, 88)]
    d.line(pts, fill=ARROW_BACKGROUND, width=7, joint="curve")
    return im


# Tipo de imagen -> función que la genera.
_RENDERERS = {
    "wow": lambda icons_dir, name: wow_icon(icons_dir, name),
    "rest": lambda icons_dir: rest_icon(),
    "home": lambda icons_dir: home_icon(),
    "arrow": lambda icons_dir, direction: arrow_icon(direction),
}


def render(spec, icons_dir):
    """Imagen de Pillow a partir de su descripción, p. ej. ("wow", "inv_misc_bag_08")."""
    kind, *args = spec
    return _RENDERERS[kind](icons_dir, *args)
