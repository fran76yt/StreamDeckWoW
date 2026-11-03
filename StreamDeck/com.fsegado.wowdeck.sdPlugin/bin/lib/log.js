/*
 * Registro a archivo
 * ==================
 * Un plugin de Stream Deck no tiene consola visible: el archivo de registro es
 * la forma práctica de diagnosticar en el equipo del usuario.
 */

const fs = require("fs");
const path = require("path");

// Devuelve una función log(...partes) que añade una línea con fecha al archivo.
// Nunca lanza: un fallo al escribir el registro no debe tumbar el plugin.
function createLogger(file) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  return (...parts) => {
    try {
      fs.appendFileSync(file, `${new Date().toISOString()} ${parts.join(" ")}\n`);
    } catch {}
  };
}

module.exports = { createLogger };
