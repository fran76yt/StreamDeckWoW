/*
 * Acción "Hueco WoW"
 * ==================
 * Lleva la cuenta de las teclas visibles de esta acción y de qué hueco
 * representa cada una, las pinta con los datos del addon y, al pulsarlas,
 * envía el atajo de su hueco.
 *
 * No sabe de dónde vienen los datos ni cómo se pulsan las teclas: recibe esas
 * piezas en el constructor (inyección de dependencias), lo que permite
 * probarla con piezas simuladas.
 */

const { NUM_SLOTS, VK, MODIFIERS, TITLE_LINE_LENGTH } = require("./constants");
const { fileToDataUrl, blankImage, textImage } = require("./images");
const { twoLines } = require("./text");

// Número de hueco de los ajustes de una tecla, limitado a 1..NUM_SLOTS.
function slotFromSettings(settings) {
  const n = Number(settings && settings.slot) || 1;
  return Math.min(Math.max(n, 1), NUM_SLOTS);
}

// Teclas a pulsar para el hueco n: modificadores + F<n>.
function keysForSlot(n) {
  return [...MODIFIERS, VK.F1 + n - 1];
}

class SlotAction {
  // sd: StreamDeck. icons: IconCache. press(vks): Promise<boolean>. log: registro.
  constructor({ sd, icons, press, log = () => {} }) {
    this.sd = sd;
    this.icons = icons;
    this.press = press;
    this.log = log;
    this.contexts = new Map();   // context de cada tecla visible -> número de hueco
    this.slots = null;           // slots del addon (null = aún no hay datos)
  }

  //--------------------------------------------------------------------------
  // Eventos de Stream Deck
  //--------------------------------------------------------------------------

  // La tecla se muestra (al abrir el perfil o cambiar de página) o el usuario
  // ha cambiado su hueco en el panel de ajustes.
  onAppear(msg) {
    this.contexts.set(msg.context, slotFromSettings(msg.payload.settings));
    this.paint(msg.context);
  }

  // La tecla deja de verse: no la pintamos más.
  onDisappear(msg) {
    this.contexts.delete(msg.context);
  }

  async onKeyDown(msg) {
    const ok = await this.press(keysForSlot(slotFromSettings(msg.payload.settings)));
    if (!ok) this.sd.showAlert(msg.context);
  }

  //--------------------------------------------------------------------------
  // Datos del addon
  //--------------------------------------------------------------------------

  setData(data) {
    this.slots = (data && data.slots) || null;
    for (const context of this.contexts.keys()) this.paint(context);
  }

  //--------------------------------------------------------------------------
  // Pintado
  //--------------------------------------------------------------------------

  // Imagen de un hueco con icono descargable; si falla, el texto de reserva.
  async iconImage(slot, n) {
    try {
      return fileToDataUrl(await this.icons.file(slot.kind, slot.id, !slot.active));
    } catch (e) {
      this.log(e.message);
      return textImage(`F${n}`);
    }
  }

  // Imagen y título del hueco n según los datos actuales.
  async render(n) {
    if (!this.slots) return { image: textImage(`F${n}`), title: "" };   // aún no se ha jugado con el addon
    const slot = this.slots[n];
    if (!slot || slot.empty) return { image: blankImage(), title: "" };
    const title = twoLines(slot.short || slot.name || "", TITLE_LINE_LENGTH);
    const hasIcon = (slot.kind === "spell" || slot.kind === "item") && slot.id;
    if (hasIcon) return { image: await this.iconImage(slot, n), title };
    // Macros y habilidades sin ID conocido: no hay icono que descargar.
    return { image: textImage(slot.kind === "macro" ? "Macro" : `F${n}`), title };
  }

  async paint(context) {
    const n = this.contexts.get(context);
    if (!n) return;
    const { image, title } = await this.render(n);
    // La descarga es asíncrona: si mientras tanto la tecla cambió de hueco o
    // desapareció, no pintamos datos viejos.
    if (this.contexts.get(context) !== n) return;
    this.sd.setImage(context, image);
    this.sd.setTitle(context, title);
  }
}

module.exports = { SlotAction, slotFromSettings, keysForSlot };
