/*
 * Utilidades de texto
 * ===================
 */

// Parte un texto en dos líneas de como mucho "max" caracteres, cortando por
// palabras y recortando con "…" lo que sobre. Pensado para títulos de teclas.
function twoLines(text, max) {
  if (!text) return "";
  if (text.length <= max) return text;
  const words = text.split(" ");
  let first = words.shift();
  while (words.length && (first + " " + words[0]).length <= max) first += " " + words.shift();
  const second = words.join(" ");
  if (!second) return first;
  // trimEnd: si el corte cae justo después de una palabra, sin espacio antes del "…".
  return `${first}\n${second.length > max ? second.slice(0, max - 1).trimEnd() + "…" : second}`;
}

module.exports = { twoLines };
