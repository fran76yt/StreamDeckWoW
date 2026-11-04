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
    this.current = null;   // { file, mtime } leído bien por última vez
    this.failed = null;    // { file, mtime } cuya lectura falló (para no repetir el aviso)
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

  // ¿Es el mismo archivo y la misma fecha que "ref"?
  static same(sv, ref) {
    return Boolean(ref) && sv.file === ref.file && sv.mtime === ref.mtime;
  }

  check() {
    const sv = newestSavedVariables(this.forever);
    if (!sv || SavedVariablesWatcher.same(sv, this.current)) return;
    try {
      const data = readAddonData(sv.file);
      // Solo se da por leído cuando la lectura ha ido bien: si falla (por
      // ejemplo, porque WoW está escribiendo justo en ese momento), se
      // reintenta en la siguiente comprobación aunque la fecha no cambie.
      this.current = sv;
      this.failed = null;
      this.log(`datos de ${sv.character} (${data && data.class})`);
      this.emit("change", data, sv);
    } catch (e) {
      // Se registra una vez por versión del archivo, no en cada reintento.
      if (!SavedVariablesWatcher.same(sv, this.failed)) this.log("no pude leer", sv.file, e.message);
      this.failed = sv;
    }
  }
}

module.exports = { SavedVariablesWatcher };
