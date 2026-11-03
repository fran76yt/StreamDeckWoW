/*
 * Iconos de WoW
 * =============
 * El juego solo nos da el ID del hechizo u objeto. Para obtener la imagen:
 *   1. Se pregunta a la API de tooltips de Wowhead el nombre del icono
 *      (spell 883 -> "ability_hunter_beastcall").
 *   2. Se descarga la imagen de su CDN.
 * Ambas cosas se guardan en disco: cada icono se descarga una sola vez y
 * después funciona sin conexión.
 */

const fs = require("fs");
const path = require("path");
const { WOWHEAD } = require("./constants");

function readJson(file) {
  try { return JSON.parse(fs.readFileSync(file, "utf8")); } catch { return {}; }
}

async function fetchOk(url) {
  const r = await fetch(url, { headers: WOWHEAD.HEADERS });
  if (!r.ok) throw new Error(`${url}: ${r.status}`);
  return r;
}

class IconCache {
  // dir: carpeta de imágenes. namesFile: caché "spell:883" -> nombre de icono.
  // dim(entrada, salida): función que genera la versión oscurecida.
  constructor({ dir, namesFile, dim }) {
    this.dir = dir;
    this.namesFile = namesFile;
    this.dim = dim;
    this.names = readJson(namesFile);
    fs.mkdirSync(dir, { recursive: true });
  }

  // Nombre del icono de un hechizo u objeto.
  async iconName(kind, id) {
    const key = `${kind}:${id}`;
    if (this.names[key]) return this.names[key];
    const { icon } = await (await fetchOk(WOWHEAD.TOOLTIP_URL(kind, id))).json();
    if (!icon) throw new Error(`wowhead ${key}: sin icono`);
    this.names[key] = icon;
    fs.writeFileSync(this.namesFile, JSON.stringify(this.names, null, 1));
    return icon;
  }

  // Ruta local de la imagen, descargándola si hace falta.
  async download(name) {
    const file = path.join(this.dir, `${name}.jpg`);
    if (!fs.existsSync(file)) {
      const r = await fetchOk(WOWHEAD.ICON_URL(name));
      fs.writeFileSync(file, Buffer.from(await r.arrayBuffer()));
    }
    return file;
  }

  // Versión oscurecida, generándola si hace falta. Si falla, la normal.
  async dimmed(name, file) {
    const out = path.join(this.dir, `${name}_dim.png`);
    if (fs.existsSync(out) || (await this.dim(file, out))) return out;
    return file;
  }

  // Ruta local del icono. dim = true para huecos que aún no tienes.
  async file(kind, id, dim = false) {
    const name = await this.iconName(kind, id);
    const file = await this.download(name);
    return dim ? this.dimmed(name, file) : file;
  }
}

module.exports = { IconCache };
