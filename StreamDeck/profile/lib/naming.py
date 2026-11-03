"""
Nombres de carpetas y archivos dentro de un perfil.
"""
import base64
import uuid

# El alfabeto de Elgato es base32hex sin la letra U: U pasa a V y V a W.
_ELGATO_ALPHABET = str.maketrans("UV", "VW")


def _elgato_id(value):
    """Identificador al estilo de Elgato: el UUID en base32hex sin relleno, con
    su alfabeto y una "Z" al final. Lo usa la aplicación para las imágenes."""
    encoded = base64.b32hexencode(uuid.UUID(value).bytes).decode().rstrip("=")
    return encoded.translate(_ELGATO_ALPHABET) + "Z"


def page_folder(page_uuid):
    """Nombre de carpeta de una página: su UUID en mayúsculas (formato V3).

    En el formato V2 (Stream Deck anterior a 7.6) era el identificador al estilo
    de Elgato; la aplicación migra los perfiles V2 a V3 al actualizarse.
    """
    return page_uuid.upper()


def image_name():
    """Nombre único para una imagen, con el mismo esquema que usa la aplicación."""
    return _elgato_id(str(uuid.uuid4())) + ".png"


def new_uuid():
    return str(uuid.uuid4())
