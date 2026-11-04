/*
 * Iconos de WoW
 * =============
 * El juego solo nos da el ID del hechizo u objeto. Para obtener la imagen:
 *   1. Se pregunta a la API de tooltips de Wowhead el nombre del icono
 *      (spell 883 -> "ability_hunter_beastcall").
 *   2. Se descarga la imagen de su CDN.
 * Ambas cosas se guardan en disco: cada icono se descarga una sola vez y
 * después funciona sin conexión.
 *
 * Cada petición tiene un tiempo límite, y un icono que falla (Wowhead caído o
 * un ID que no conoce) no se vuelve a pedir hasta pasado un rato: si no, se
 * repetiría la petición en cada repintado.
 */

const fs = require("fs");
const path = require("path");
const { WOWHEAD } = require("./constants");

function readJson(file) {
  try { return JSON.parse(fs.readFileSync(file, "utf8")); } catch { return {}; }
}

async function fetchOk(url) {
  const r = await fetch(url, { headers: WOWHEAD.HEADERS, signal: AbortSignal.timeout(WOWHEAD.TIMEOUT_MS) });
  if (!r.ok) throw new Error(`${url}: ${r.status}`);
  return r;
}

// Guarda un archivo con un nombre temporal y lo renombra al final: si algo
// falla a mitad, no queda un archivo a medias que parezca bueno.
function writeAtomic(file, data) {
  fs.writeFileSync(file + ".tmp", data);
  fs.renameSync(file + ".tmp", file);
}

class IconCache {
  // dir: carpeta de imágenes. namesFile: caché "spell:883" -> nombre de icono.
  // size: lado de las imágenes oscurecidas.
  // dim(entrada, salida, lado): función que genera la versión oscurecida.
  constructor({ dir, namesFile, size, dim }) {
    this.dir = dir;
    this.namesFile = namesFile;
    this.size = size;
    this.dim = dim;
    this.names = readJson(namesFile);
    this.failures = new Map();   // "spell:883" -> momento del último fallo
    this.inFlight = new Map();   // "spell:883:dim" -> promesa de la petición en curso
    fs.mkdirSync(dir, { recursive: true });
  }

  // ¿Falló hace poco? Entonces no se vuelve a intentar todavía.
  recentlyFailed(key) {
    const at = this.failures.get(key);
    return at !== undefined && Date.now() - at < WOWHEAD.RETRY_AFTER_MS;
  }

  // Nombre del icono de un hechizo u objeto.
  async iconName(kind, id) {
    const key = `${kind}:${id}`;
    if (this.names[key]) return this.names[key];
    const { icon } = await (await fetchOk(WOWHEAD.TOOLTIP_URL(kind, id))).json();
    if (!icon) throw new Error(`wowhead ${key}: sin icono`);
    this.names[key] = icon;
    writeAtomic(this.namesFile, JSON.stringify(this.names, null, 1));
    return icon;
  }

  // Ruta local de la imagen, descargándola si hace falta. Solo se guarda si la
  // respuesta es una imagen: un portal cautivo o un proxy que devuelva una
  // página web no debe quedar en la caché como si fuera el icono.
  async download(name) {
    const file = path.join(this.dir, `${name}.jpg`);
    if (!fs.existsSync(file)) {
      const r = await fetchOk(WOWHEAD.ICON_URL(name));
      const type = r.headers.get("content-type") || "";
      if (!type.startsWith("image/")) throw new Error(`icono ${name}: la respuesta no es una imagen (${type || "sin tipo"})`);
      writeAtomic(file, Buffer.from(await r.arrayBuffer()));
    }
    return file;
  }

  // Versión oscurecida, generándola si hace falta. Si falla, la normal.
  async dimmed(name, file) {
    const out = path.join(this.dir, `${name}_dim.png`);
    if (fs.existsSync(out) || (await this.dim(file, out, this.size))) return out;
    return file;
  }

  // Ruta local del icono. dim = true para huecos que aún no tienes.
  // Lanza un error si no se puede obtener (o si falló hace poco).
  // Si ya hay una petición en curso para el mismo icono, se comparte: así dos
  // teclas con el mismo hueco no descargan ni oscurecen el mismo archivo a la
  // vez (dos escrituras simultáneas podrían dejarlo corrupto).
  file(kind, id, dim = false) {
    const flightKey = `${kind}:${id}:${dim ? "dim" : "color"}`;
    if (!this.inFlight.has(flightKey)) {
      const p = this.fetchFile(kind, id, dim).finally(() => this.inFlight.delete(flightKey));
      this.inFlight.set(flightKey, p);
    }
    return this.inFlight.get(flightKey);
  }

  async fetchFile(kind, id, dim) {
    const key = `${kind}:${id}`;
    if (this.recentlyFailed(key)) throw new Error(`${key}: falló hace poco, no se reintenta todavía`);
    try {
      const name = await this.iconName(kind, id);
      const file = await this.download(name);
      this.failures.delete(key);
      return dim ? this.dimmed(name, file) : file;
    } catch (e) {
      this.failures.set(key, Date.now());
      throw e;
    }
  }
}

module.exports = { IconCache };
