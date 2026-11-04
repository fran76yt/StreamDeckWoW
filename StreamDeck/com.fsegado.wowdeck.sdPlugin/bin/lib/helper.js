/*
 * Proceso auxiliar de Windows (helper.ps1)
 * ========================================
 * Node no puede simular pulsaciones de teclado sin módulos nativos (que habría
 * que compilar para cada versión de Node). En su lugar mantenemos abierto un
 * proceso de PowerShell que llama a la API de Windows. Arrancarlo cuesta un
 * segundo, pero solo se hace una vez; después cada orden tarda milisegundos.
 *
 * Protocolo (UTF-8): al arrancar el proceso escribe "READY"; después, por cada
 * orden escrita en stdin, una línea en stdout: "OK ..." o "ERR ...". Las
 * respuestas llegan en el mismo orden que las órdenes, así que basta una cola
 * de callbacks.
 *
 * Cada proceso tiene su propia cola. Si el proceso muere, las órdenes
 * pendientes se resuelven como fallidas y la cola se descarta: así una
 * respuesta del proceso nuevo nunca se entrega a una orden del anterior.
 */

const { spawn } = require("child_process");
const { HELPER_RESTART_MS, HELPER_RESTART_MAX_MS } = require("./constants");

class Helper {
  // script: ruta de helper.ps1. log: función de registro.
  constructor(script, log = () => {}) {
    this.script = script;
    this.log = log;
    this.proc = null;   // proceso actual (null mientras no hay uno vivo)
    this.queue = null;  // callbacks pendientes del proceso actual
    this.restartDelay = HELPER_RESTART_MS;   // crece si se cae una y otra vez
  }

  start() {
    const proc = spawn("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", this.script], { windowsHide: true });
    const queue = [];
    let buffer = "";
    this.proc = proc;
    this.queue = queue;

    proc.stdout.setEncoding("utf8");
    // stdout llega en trozos arbitrarios: acumulamos y procesamos por líneas.
    proc.stdout.on("data", (chunk) => {
      buffer += chunk;
      let nl;
      while ((nl = buffer.indexOf("\n")) >= 0) {
        this.onLine(queue, buffer.slice(0, nl).trim());
        buffer = buffer.slice(nl + 1);
      }
    });
    // Hay que leer stderr aunque no se espere nada: si se llena la tubería, el
    // proceso se bloquea. Además, así sus errores quedan en el registro.
    proc.stderr.setEncoding("utf8");
    proc.stderr.on("data", (d) => this.log("helper stderr:", String(d).trim()));
    // "error" del proceso salta si no se pudo lanzar; los fallos al escribir en
    // su stdin (por ejemplo, porque acaba de morir) llegan por proc.stdin.
    // "close" limpia y relanza.
    proc.on("error", (e) => {
      this.log("helper error:", e.message);
      // Sin pid, el proceso ni siquiera llegó a arrancar: se trata como si
      // hubiera terminado (onExit ignora la segunda llamada si también llega "close").
      if (proc.pid === undefined) this.onExit(proc, queue, null);
    });
    proc.stdin.on("error", (e) => this.log("helper stdin:", e.message));
    proc.on("close", (code) => this.onExit(proc, queue, code));
    return this;
  }

  onLine(queue, line) {
    if (line === "READY") {
      this.restartDelay = HELPER_RESTART_MS;   // ha arrancado bien: la espera vuelve al mínimo
      return this.log("helper listo");
    }
    if (line.startsWith("ERR")) this.log("helper:", line);
    const done = queue.shift();
    if (done) done(line.startsWith("OK"));
  }

  // El proceso ha terminado: falla lo pendiente de ESA cola y relanza, cada
  // vez esperando el doble (hasta un máximo) mientras no llegue a arrancar.
  onExit(proc, queue, code) {
    if (this.proc !== proc) return;   // ya se ha sustituido
    this.log(`helper terminó (${code}); se relanza en ${this.restartDelay} ms`);
    this.proc = null;
    this.queue = null;
    while (queue.length) queue.shift()(false);
    setTimeout(() => this.start(), this.restartDelay);
    this.restartDelay = Math.min(this.restartDelay * 2, HELPER_RESTART_MAX_MS);
  }

  isAlive() {
    return this.proc !== null && this.proc.stdin.writable;
  }

  // Envía una orden y resuelve con true/false según la respuesta. Si no hay un
  // proceso vivo, falla en el acto en lugar de dejar la orden esperando.
  command(line) {
    if (!this.isAlive()) return Promise.resolve(false);
    const queue = this.queue;
    return new Promise((resolve) => {
      queue.push(resolve);
      this.proc.stdin.write(line + "\n");
    });
  }

  // Pulsa las teclas (códigos VK) en orden y las suelta al revés.
  pressKeys(vks) {
    return this.command(`KEYS ${vks.join(",")}`);
  }

  // Guarda una copia gris y oscurecida de una imagen, de size x size píxeles.
  dimImage(input, output, size) {
    return this.command(`DIM ${input}|${output}|${size}`);
  }
}

module.exports = { Helper };
