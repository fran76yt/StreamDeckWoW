"""
Nombres de carpetas y archivos dentro de un perfil.
"""
import base64
import uuid

# El alfabeto de Elgato es base32hex sin la letra U: U pasa a V y V a W.
_ELGATO_ALPHABET = str.maketrans("UV", "VW")


def page_folder(page_uuid):
    """Nombre de carpeta de una página a partir de su UUID.

    Es el UUID (16 bytes) en base32hex sin relleno, con el alfabeto de Elgato
    y una "Z" al final. Si no coincide, la aplicación no encuentra la página.
    """
    encoded = base64.b32hexencode(uuid.UUID(page_uuid).bytes).decode().rstrip("=")
    return encoded.translate(_ELGATO_ALPHABET) + "Z"


def image_name():
    """Nombre único para una imagen, con el mismo esquema que usa la aplicación."""
    return page_folder(str(uuid.uuid4())) + ".png"


def new_uuid():
    return str(uuid.uuid4())
