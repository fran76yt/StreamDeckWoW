"""
Atajos de teclado en el formato de la acción "Hotkey" de Elgato.
"""
from .constants import VK, QT, MOD_SHIFT, MOD_CTRL, HOTKEY_SLOTS, EMPTY_HOTKEY


def key(name, ctrl=False, shift=False):
    """Atajo para la tecla "name" (ver VK en constants.py) con modificadores."""
    vk = VK[name]
    return {"KeyCmd": False, "KeyCtrl": ctrl, "KeyModifiers": (MOD_SHIFT if shift else 0) | (MOD_CTRL if ctrl else 0),
            "KeyOption": False, "KeyShift": shift, "NativeCode": vk,
            "QTKeyCode": QT.get(name, vk), "VKeyCode": vk}


def pad(hotkeys):
    """Completa la lista hasta los 4 atajos que exige la acción."""
    return (list(hotkeys) + [EMPTY_HOTKEY] * HOTKEY_SLOTS)[:HOTKEY_SLOTS]
