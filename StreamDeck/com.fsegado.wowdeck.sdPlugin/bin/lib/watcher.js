/*
 * Vigilancia de las SavedVariables
 * ================================
 * Comprueba periódicamente la fecha de modificación de las SavedVariables más
 * recientes y, cuando cambia (el jugador hizo /reload o salió), las lee y
 * emite "change" con los datos del addon.
 */

const { EventEmitter } = require("events");
const { newestSavedVariables, readAddonData } = require("./wow");

class SavedVariablesWatcher extends EventEmitter {
  constructor(forever, intervalMs, log = () => {}) {
    super();
    this.forever = forever;
    this.intervalMs = intervalMs;
    this.log = log;
    this.current = null;   // { file, mtime } leído por última vez
    this.timer = null;
  }

  start() {
    this.check();
    this.timer = setInterval(() => this.check(), this.intervalMs);
    return this;
  }

  stop() {
    clearInterval(this.timer);
  }

  // ¿Es el mismo archivo y la misma fecha que la última vez?
  isUnchanged(sv) {
    return this.current && sv.file === this.current.file && sv.mtime === this.current.mtime;
  }

  check() {
    const sv = newestSavedVariables(this.forever);
    if (!sv || this.isUnchanged(sv)) return;
    this.current = sv;
    try {
      const data = readAddonData(sv.file);
      this.log(`datos de ${sv.character} (${data && data.class})`);
      this.emit("change", data, sv);
    } catch (e) {
      // Puede pasar si leemos justo mientras WoW escribe. Cuando termina, la
      // fecha vuelve a cambiar y en la siguiente comprobación se lee completo.
      this.log("no pude leer", sv.file, e.message);
    }
  }
}

module.exports = { SavedVariablesWatcher };
