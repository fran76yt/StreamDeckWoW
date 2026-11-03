/*
 * Lector de SavedVariables de WoW
 * ===============================
 *
 * WoW guarda las SavedVariables como código Lua que reconstruye las tablas:
 *
 *   StreamDeckWoWChar = {
 *       ["class"] = "HUNTER",
 *       ["slots"] = {
 *           {
 *               ["active"] = true,
 *               ["id"] = 6948,
 *           }, -- [1]
 *       },
 *   }
 *
 * No necesitamos un intérprete de Lua: el formato es un subconjunto pequeño y
 * predecible (tablas, textos, números, booleanos y nil). Este es un analizador
 * descendente recursivo mínimo que lo convierte en objetos de JavaScript.
 *
 * Convenciones:
 *   - Las tablas se devuelven como objetos JS.
 *   - Los valores sin clave ("arrays" de Lua) usan las claves 1, 2, 3...
 *     como en Lua, no 0, 1, 2. Así slots[1] es el hueco 1 en ambos lados.
 *   - nil se devuelve como null.
 */

// Busca "Nombre = ..." al principio de una línea y devuelve el valor asignado.
// El archivo puede contener varias variables; solo leemos la que nos interesa.
function parseAssignment(src, name) {
  const re = new RegExp("^\\s*" + name + "\\s*=", "m");
  const m = re.exec(src);
  if (!m) return undefined;
  const p = new Parser(src, m.index + m[0].length);
  return p.value();
}

class Parser {
  constructor(src, pos) {
    this.s = src;  // texto completo
    this.i = pos;  // posición actual
  }

  // Salta espacios y comentarios de línea ("-- [1]" es un comentario que WoW
  // añade para indicar la posición; no aporta nada).
  skip() {
    for (;;) {
      while (this.i < this.s.length && /\s/.test(this.s[this.i])) this.i++;
      if (this.s.startsWith("--", this.i)) {
        const nl = this.s.indexOf("\n", this.i);
        this.i = nl < 0 ? this.s.length : nl + 1;
      } else return;
    }
  }

  fail(msg) {
    throw new Error(`${msg} (posición ${this.i})`);
  }

  // value := tabla | texto | número | true | false | nil
  value() {
    this.skip();
    const c = this.s[this.i];
    if (c === "{") return this.table();
    if (c === '"' || c === "'") return this.string();
    // Literales: miramos una ventana corta en vez de cortar todo el texto.
    const m = /^(?:true|false|nil|-?(?:0x[0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+))/.exec(this.s.slice(this.i, this.i + 40));
    if (!m) this.fail("valor no reconocido");
    this.i += m[0].length;
    if (m[0] === "true") return true;
    if (m[0] === "false") return false;
    if (m[0] === "nil") return null;
    return Number(m[0]);
  }

  // Texto entre comillas con los escapes que usa Lua: \n, \t, \r, \", \\ y
  // \ddd (código decimal de un byte). WoW escribe el texto en UTF-8 tal cual,
  // así que los acentos no llegan escapados.
  string() {
    const q = this.s[this.i++];
    let out = "";
    while (this.i < this.s.length) {
      const c = this.s[this.i++];
      if (c === q) return out;
      if (c !== "\\") { out += c; continue; }
      const e = this.s[this.i++];
      if (e === "n") out += "\n";
      else if (e === "t") out += "\t";
      else if (e === "r") out += "\r";
      else if (e === "\n") out += "\n";            // barra invertida + salto de línea real
      else if (/\d/.test(e)) {
        let d = e;
        while (d.length < 3 && /\d/.test(this.s[this.i])) d += this.s[this.i++];
        out += String.fromCharCode(Number(d));
      } else out += e;                               // \" \' \\ y cualquier otro
    }
    this.fail("texto sin cerrar");
  }

  // tabla := "{" { campo [","|";"] } "}"
  // campo := "[" value "]" "=" value   (clave explícita, lo que usa WoW)
  //        | nombre "=" value          (clave como identificador)
  //        | value                     (posición siguiente: 1, 2, 3...)
  table() {
    this.i++; // {
    const t = {};
    let n = 1;
    for (;;) {
      this.skip();
      if (this.s[this.i] === "}") { this.i++; return t; }
      if (this.s[this.i] === "[") {
        this.i++;
        const key = this.value();
        this.skip();
        if (this.s[this.i++] !== "]") this.fail("falta ]");
        this.skip();
        if (this.s[this.i++] !== "=") this.fail("falta =");
        t[key] = this.value();
      } else {
        // "nombre =" pero no "nombre ==": el (?!=) evita confundirlo con una comparación.
        const id = /^[A-Za-z_]\w*\s*=(?!=)/.exec(this.s.slice(this.i, this.i + 80));
        if (id) {
          this.i += id[0].length;
          t[id[0].replace(/\s*=$/, "")] = this.value();
        } else {
          t[n++] = this.value();
        }
      }
      this.skip();
      if (this.s[this.i] === "," || this.s[this.i] === ";") this.i++;
    }
  }
}

module.exports = { parseAssignment };
