"""
Iconos de WoW desde Wowhead.

Las teclas fijas del perfil (Mochilas, diales...) usan iconos del juego. Son
arte de Blizzard, así que no van en el repositorio: se descargan de la CDN de
Wowhead la primera vez que hacen falta y se guardan en la carpeta de iconos.

Cada descarga se comprueba antes de darla por buena (que sea una imagen que
Pillow pueda abrir) y se escribe con un nombre temporal: un portal cautivo o
un proxy que devuelva una página web no deja un "icono" roto en la caché.
"""
import io
import os
import urllib.request

from PIL import Image

from .constants import WOWHEAD_ICON_URL, WOWHEAD_HEADERS, WOWHEAD_TIMEOUT_S


def layout_icons(layout):
    """Nombres de los iconos de WoW que usa un layout (teclas y diales)."""
    items = [k for page in layout["pages"] for k in page if k] + list(layout.get("dials", []))
    return sorted({item["image"][1] for item in items if item.get("image", (None,))[0] == "wow"})


def _fetch_image(name):
    """Bytes del icono, comprobados como imagen. Lanza ValueError si no lo son."""
    request = urllib.request.Request(WOWHEAD_ICON_URL.format(name=name), headers=WOWHEAD_HEADERS)
    with urllib.request.urlopen(request, timeout=WOWHEAD_TIMEOUT_S) as response:
        content_type = response.headers.get("Content-Type", "")
        data = response.read()
    if not content_type.startswith("image/"):
        raise ValueError(f"la respuesta no es una imagen ({content_type or 'sin tipo'})")
    try:
        Image.open(io.BytesIO(data)).verify()
    except Exception as e:   # Pillow lanza tipos distintos según el formato
        raise ValueError(f"la imagen descargada no es válida ({e})") from e
    return data


def download_icon(name, icons_dir):
    """Descarga un icono como <icons_dir>/<name>.jpg, solo si es una imagen válida."""
    data = _fetch_image(name)
    path = os.path.join(icons_dir, name + ".jpg")
    with open(path + ".tmp", "wb") as fh:
        fh.write(data)
    os.replace(path + ".tmp", path)


def ensure_icons(layout, icons_dir):
    """Descarga los iconos del layout que aún no estén en icons_dir.

    Devuelve los nombres descargados. Si no hay conexión o la respuesta no es
    válida, el error sale con el nombre del icono que falta, en vez de un
    FileNotFoundError al dibujar.
    """
    os.makedirs(icons_dir, exist_ok=True)
    missing = [n for n in layout_icons(layout) if not os.path.exists(os.path.join(icons_dir, n + ".jpg"))]
    for name in missing:
        try:
            download_icon(name, icons_dir)
        except (OSError, ValueError) as e:
            raise SystemExit(f'No pude descargar el icono "{name}" de Wowhead: {e}')
    return missing
