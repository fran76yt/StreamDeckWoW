/*
 * Imágenes para las teclas
 * ========================
 * setImage de Stream Deck acepta imágenes como data URL (base64 o SVG). Aquí
 * están las conversiones y las imágenes generadas al vuelo.
 */

const fs = require("fs");
const { IMAGE } = require("./constants");

const MIME = { ".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg" };

// Archivo local -> data URL en base64.
function fileToDataUrl(file) {
  const ext = file.slice(file.lastIndexOf(".")).toLowerCase();
  return `data:${MIME[ext] || "image/png"};base64,${fs.readFileSync(file).toString("base64")}`;
}

function svgToDataUrl(svg) {
  return "data:image/svg+xml;charset=utf8," + encodeURIComponent(svg);
}

// El texto va dentro de XML: quitamos los caracteres que lo romperían.
function escapeXml(text) {
  return text.replace(/[<&>]/g, "");
}

// Fondo liso, para huecos vacíos.
function blankImage() {
  const s = IMAGE.SIZE;
  return svgToDataUrl(`<svg xmlns="http://www.w3.org/2000/svg" width="${s}" height="${s}"><rect width="${s}" height="${s}" fill="${IMAGE.BLANK_COLOR}"/></svg>`);
}

// Texto centrado, para huecos sin icono (macros, datos aún no disponibles).
function textImage(text) {
  const s = IMAGE.SIZE;
  return svgToDataUrl(
    `<svg xmlns="http://www.w3.org/2000/svg" width="${s}" height="${s}"><rect width="${s}" height="${s}" fill="${IMAGE.TEXT_BACKGROUND}"/>` +
    `<text x="${s / 2}" y="${s * 0.55}" font-family="Segoe UI, Arial" font-size="30" font-weight="bold" fill="${IMAGE.TEXT_COLOR}" text-anchor="middle">${escapeXml(text)}</text></svg>`);
}

module.exports = { fileToDataUrl, blankImage, textImage };
