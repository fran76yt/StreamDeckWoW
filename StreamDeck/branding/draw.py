"""
Dibujo del icono: una Stream Deck en miniatura (6 teclas) con marco dorado al
estilo de los iconos de WoW, y dos teclas encendidas.

Cada elemento es una función que dibuja sobre una capa RGBA; icon() las
compone. Todo se dibuja a MASTER_SIZE y se reduce después.
"""
from PIL import Image, ImageDraw, ImageFilter

from constants import (MASTER_SIZE, BG_TOP, BG_BOTTOM, GOLD_DARK, GOLD, GOLD_LIGHT,
                       KEY_TOP, KEY_BOTTOM, KEY_EDGE, GLYPH, WHITE,
                       CORNER_RADIUS, FRAME_WIDTH, FRAME_HIGHLIGHT_WIDTH, FRAME_HIGHLIGHT_ALPHA,
                       GRID_COLUMNS, GRID_ROWS, KEY_SIZE, KEY_GAP, KEY_RADIUS, GLOW_BLUR, LIT_KEYS)


# --------------------------------------------------------------------------
# Utilidades genéricas
# --------------------------------------------------------------------------
def layer(size=MASTER_SIZE):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def mix(a, b, t):
    """Color intermedio entre a y b (t de 0 a 1)."""
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(box, top, bottom):
    """Capa con un degradado vertical que ocupa box (x0, y0, x1, y1)."""
    x0, y0, x1, y1 = box
    im = layer()
    d = ImageDraw.Draw(im)
    for y in range(y0, y1):
        d.line([(x0, y), (x1, y)], fill=mix(top, bottom, (y - y0) / max(1, y1 - y0 - 1)) + (255,))
    return im


def rounded_mask(box, radius):
    """Máscara (L) con un rectángulo redondeado."""
    m = Image.new("L", (MASTER_SIZE, MASTER_SIZE), 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius, fill=255)
    return m


def fill_rounded(base, box, radius, top, bottom):
    """Rectángulo redondeado con degradado vertical, compuesto sobre base."""
    base.paste(vertical_gradient(box, top, bottom), (0, 0), rounded_mask(box, radius))


def glow(base, box, radius, color, blur=GLOW_BLUR):
    """Halo de luz alrededor de box: la forma, desenfocada, compuesta debajo."""
    g = layer()
    ImageDraw.Draw(g).rounded_rectangle(box, radius, fill=color + (255,))
    base.alpha_composite(g.filter(ImageFilter.GaussianBlur(blur)))


# --------------------------------------------------------------------------
# Elementos del icono
# --------------------------------------------------------------------------
def key_boxes():
    """Caja de cada tecla de la rejilla, centrada: {(col, fila): (x0, y0, x1, y1)}."""
    width = GRID_COLUMNS * KEY_SIZE + (GRID_COLUMNS - 1) * KEY_GAP
    height = GRID_ROWS * KEY_SIZE + (GRID_ROWS - 1) * KEY_GAP
    left, top = (MASTER_SIZE - width) // 2, (MASTER_SIZE - height) // 2
    boxes = {}
    for col in range(GRID_COLUMNS):
        for row in range(GRID_ROWS):
            x, y = left + col * (KEY_SIZE + KEY_GAP), top + row * (KEY_SIZE + KEY_GAP)
            boxes[(col, row)] = (x, y, x + KEY_SIZE, y + KEY_SIZE)
    return boxes


def background(base):
    inset = FRAME_WIDTH // 2
    fill_rounded(base, (inset, inset, MASTER_SIZE - inset, MASTER_SIZE - inset), CORNER_RADIUS, BG_TOP, BG_BOTTOM)


def frame(base):
    """Marco dorado con un filo claro por dentro, como los marcos de WoW."""
    d = ImageDraw.Draw(base)
    half = FRAME_WIDTH // 2
    d.rounded_rectangle((half, half, MASTER_SIZE - half, MASTER_SIZE - half), CORNER_RADIUS,
                        outline=GOLD_DARK + (255,), width=FRAME_WIDTH)
    d.rounded_rectangle((half + 3, half + 3, MASTER_SIZE - half - 3, MASTER_SIZE - half - 3), CORNER_RADIUS - 3,
                        outline=GOLD + (255,), width=FRAME_WIDTH - 8)
    # El filo es semitransparente: se dibuja en una capa aparte y se compone
    # encima. Dibujado directamente, Pillow escribiría el píxel con su alfa en
    # lugar de mezclarlo, y el icono quedaría transparente en ese anillo.
    highlight = layer()
    inner = FRAME_WIDTH + 1
    ImageDraw.Draw(highlight).rounded_rectangle(
        (inner, inner, MASTER_SIZE - inner, MASTER_SIZE - inner), CORNER_RADIUS - FRAME_WIDTH // 2,
        outline=GOLD_LIGHT + (FRAME_HIGHLIGHT_ALPHA,), width=FRAME_HIGHLIGHT_WIDTH)
    base.alpha_composite(highlight)


def bolt(box):
    """Rayo (símbolo de "acción instantánea") dentro de box."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    pts = [(0.58, 0.12), (0.28, 0.55), (0.48, 0.55), (0.40, 0.88), (0.72, 0.42), (0.52, 0.42)]
    return [(x0 + px * w, y0 + py * h) for px, py in pts]


def dark_key(base, box):
    fill_rounded(base, box, KEY_RADIUS, KEY_TOP, KEY_BOTTOM)
    ImageDraw.Draw(base).rounded_rectangle(box, KEY_RADIUS, outline=KEY_EDGE + (255,), width=3)


def lit_key(base, box, color, core, with_glyph):
    glow(base, box, KEY_RADIUS, color)
    fill_rounded(base, box, KEY_RADIUS, core, color)
    d = ImageDraw.Draw(base)
    d.rounded_rectangle(box, KEY_RADIUS, outline=core + (255,), width=3)
    if with_glyph:
        d.polygon(bolt(box), fill=GLYPH + (255,))


def keys(base):
    # Primero las apagadas y después las encendidas, para que el brillo quede encima.
    boxes = key_boxes()
    for pos, box in boxes.items():
        if pos not in LIT_KEYS:
            dark_key(base, box)
    for pos, (color, core, with_glyph) in LIT_KEYS.items():
        lit_key(base, boxes[pos], color, core, with_glyph)


# --------------------------------------------------------------------------
# Iconos completos
# --------------------------------------------------------------------------
def icon():
    """Icono a color a MASTER_SIZE."""
    base = layer()
    background(base)
    keys(base)
    frame(base)
    # Recorte final con la forma redondeada, para que el halo no se salga.
    out = layer()
    out.paste(base, (0, 0), rounded_mask((0, 0, MASTER_SIZE, MASTER_SIZE), CORNER_RADIUS))
    return out


def mono_icon():
    """Silueta blanca: contorno de las teclas y las encendidas rellenas."""
    base = layer()
    d = ImageDraw.Draw(base)
    for pos, box in key_boxes().items():
        if pos in LIT_KEYS:
            d.rounded_rectangle(box, KEY_RADIUS, fill=WHITE + (255,))
        else:
            d.rounded_rectangle(box, KEY_RADIUS, outline=WHITE + (255,), width=18)
    return base


def resized(im, size):
    return im.resize((size, size), Image.LANCZOS)
