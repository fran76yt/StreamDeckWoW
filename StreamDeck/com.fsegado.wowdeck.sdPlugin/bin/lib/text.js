/*
 * Utilidades de texto
 * ===================
 */

// Recorta un texto a "max" caracteres como mucho, terminando en "…" si sobra.
// trimEnd: si el corte cae justo después de una palabra, sin espacio antes del "…".
function truncate(text, max) {
  return text.length > max ? text.slice(0, max - 1).trimEnd() + "…" : text;
}

// Parte un texto en dos líneas de como mucho "max" caracteres cada una,
// cortando por palabras. Una palabra más larga que una línea se recorta.
// Pensado para títulos de teclas.
function twoLines(text, max) {
  if (!text) return "";
  if (text.length <= max) return text;
  const words = text.split(" ");
  let first = words.shift();
  while (words.length && (first + " " + words[0]).length <= max) first += " " + words.shift();
  const second = words.join(" ");
  if (!second) return truncate(first, max);
  return `${truncate(first, max)}\n${truncate(second, max)}`;
}

module.exports = { twoLines, truncate };
