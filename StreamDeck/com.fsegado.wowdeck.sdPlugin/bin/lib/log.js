/*
 * Registro
 * ========
 * Un plugin de Stream Deck no tiene consola visible. Cada línea se escribe:
 *   - en nuestro archivo de registro, y
 *   - por la salida estándar, que Stream Deck (7.6+) guarda en su propio
 *     registro del plugin (logs\com.fsegado.wowdeck0.log). Así queda rastro
 *     aunque falle la escritura de nuestro archivo.
 *
 * Para que el archivo no crezca sin límite, al pasar de maxBytes se renombra a
 * <archivo>.old (sustituyendo al anterior) y se empieza uno nuevo.
 */

const fs = require("fs");
const path = require("path");

// Si el archivo supera maxBytes, lo aparta como .old.
function rotateIfNeeded(file, maxBytes) {
  try {
    if (fs.statSync(file).size > maxBytes) fs.renameSync(file, file + ".old");
  } catch {} // aún no existe: nada que rotar
}

// Devuelve una función log(...partes). Nunca lanza: un fallo al escribir el
// registro no debe tumbar el plugin.
function createLogger(file, maxBytes) {
  try { fs.mkdirSync(path.dirname(file), { recursive: true }); } catch {}
  return (...parts) => {
    const line = `${new Date().toISOString()} ${parts.join(" ")}`;
    console.log(line);
    try {
      rotateIfNeeded(file, maxBytes);
      fs.appendFileSync(file, line + "\n");
    } catch {}
  };
}

module.exports = { createLogger };
