/*
 * Proceso auxiliar de Windows (helper.ps1)
 * ========================================
 * Node no puede simular pulsaciones de teclado sin módulos nativos (que habría
 * que compilar para cada versión de Node). En su lugar mantenemos abierto un
 * proceso de PowerShell que llama a la API de Windows. Arrancarlo cuesta un
 * segundo, pero solo se hace una vez; después cada orden tarda milisegundos.
 *
 * Protocolo: una orden por línea en stdin y una respuesta por línea en stdout
 * ("OK ..." o "ERR ..."). Las respuestas llegan en el mismo orden que las
 * órdenes, así que basta una cola de callbacks.
 */

const { spawn } = require("child_process");

const RESTART_DELAY_MS = 1000;

class Helper {
  // script: ruta de helper.ps1. log: función de registro.
  constructor(script, log = () => {}) {
    this.script = script;
    this.log = log;
    this.proc = null;
    this.waiting = [];
    this.buffer = "";
  }

  start() {
    this.proc = spawn("powershell.exe", ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", this.script], { windowsHide: true });
    this.proc.stdout.on("data", (chunk) => this.onData(chunk));
    this.proc.on("exit", (code) => this.onExit(code));
    return this;
  }

  // stdout llega en trozos arbitrarios: acumulamos y procesamos por líneas.
  onData(chunk) {
    this.buffer += chunk;
    let nl;
    while ((nl = this.buffer.indexOf("\n")) >= 0) {
      this.onLine(this.buffer.slice(0, nl).trim());
      this.buffer = this.buffer.slice(nl + 1);
    }
  }

  onLine(line) {
    if (line === "READY") return this.log("helper listo");
    if (line.startsWith("ERR")) this.log("helper:", line);
    const done = this.waiting.shift();
    if (done) done(line.startsWith("OK"));
  }

  // Si el proceso muere, fallamos lo pendiente y lo relanzamos.
  onExit(code) {
    this.log("helper terminó", code);
    while (this.waiting.length) this.waiting.shift()(false);
    setTimeout(() => this.start(), RESTART_DELAY_MS);
  }

  // Envía una orden y resuelve con true/false según la respuesta.
  command(line) {
    return new Promise((resolve) => {
      this.waiting.push(resolve);
      this.proc.stdin.write(line + "\n");
    });
  }

  // Pulsa las teclas (códigos VK) en orden y las suelta al revés.
  pressKeys(vks) {
    return this.command(`KEYS ${vks.join(",")}`);
  }

  // Guarda una copia gris y oscurecida de una imagen.
  dimImage(input, output) {
    return this.command(`DIM ${input}|${output}`);
  }
}

module.exports = { Helper };
