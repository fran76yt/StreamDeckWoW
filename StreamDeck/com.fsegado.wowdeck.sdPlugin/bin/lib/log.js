/*
 * Registro
 * ========
 * Un plugin de Stream Deck no tiene consola visible. Cada línea se escribe:
 *   - en nuestro archivo de registro, y
 *   - por la salida estándar, que Stream Deck (7.6+) guarda en su propio
 *     registro del plugin (logs\com.fsegado.wowdeck0.log). Así queda rastro
 *     aunque falle la escritura de nuestro archivo.
 */

const fs = require("fs");
const path = require("path");

// Devuelve una función log(...partes). Nunca lanza: un fallo al escribir el
// registro no debe tumbar el plugin.
function createLogger(file) {
  try { fs.mkdirSync(path.dirname(file), { recursive: true }); } catch {}
  return (...parts) => {
    const line = `${new Date().toISOString()} ${parts.join(" ")}`;
    console.log(line);
    try { fs.appendFileSync(file, line + "\n"); } catch {}
  };
}

module.exports = { createLogger };
