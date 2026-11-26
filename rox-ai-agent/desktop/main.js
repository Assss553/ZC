// ROX AI Agent — Electron shell. Starts the Python backend on 127.0.0.1 with a random per-launch token.
const { app, BrowserWindow, globalShortcut, ipcMain, dialog, Menu } = require("electron");
const { spawn } = require("child_process");
const crypto = require("crypto");
const path = require("path");
const fs = require("fs");
const http = require("http");

const PORT = Number(process.env.ROX_PORT || 8765);
const TOKEN = crypto.randomBytes(24).toString("hex");
let backend = null, win = null;

function backendCommand() {
  const packed = path.join(process.resourcesPath || "", "backend", process.platform === "win32" ? "rox-backend.exe" : "rox-backend");
  if (app.isPackaged && fs.existsSync(packed)) return { cmd: packed, args: [], cwd: path.dirname(packed) };
  const root = path.join(__dirname, "..", "backend");
  const py = process.platform === "win32" ? path.join(root, ".venv", "Scripts", "python.exe") : path.join(root, ".venv", "bin", "python");
  if (!fs.existsSync(py)) return { missing: `Python environment not found:\n${py}\n\nRun scripts\\setup.ps1 first, or use the ROX installer (.exe) which includes everything.` };
  return { cmd: py, args: ["run_backend.py"], cwd: root };
}

let backendOut = "";
function startBackend() {
  const b = backendCommand();
  if (b.missing) { backendOut = b.missing; return; }
  const { cmd, args, cwd } = b;
  const env = { ...process.env, ROX_TOKEN: TOKEN, ROX_PORT: String(PORT), ROX_EXE_PATH: process.execPath, PYTHONUTF8: "1" };
  backend = spawn(cmd, args, { cwd, env, windowsHide: true });
  const log = fs.createWriteStream(path.join(app.getPath("userData"), "backend.log"), { flags: "a" });
  const keep = (d) => { backendOut = (backendOut + d.toString()).slice(-4000); log.write(d); };
  backend.stdout.on("data", keep); backend.stderr.on("data", keep);
  backend.on("error", (e) => { backendOut += `\nFailed to launch backend: ${e.message}`; });
  backend.on("exit", (code) => { if (!app.isQuitting && app.backendReady) dialog.showErrorBox("ROX backend stopped", `Exit code ${code}.\n\n${backendOut.slice(-1500)}`); });
}

function post(p) {
  const req = http.request({ host: "127.0.0.1", port: PORT, path: p, method: "POST", headers: { "x-rox-token": TOKEN, "content-type": "application/json" } });
  req.on("error", () => {}); req.end("{}");
}

function waitReady(tries = 240) { // up to 60s: first start of a packaged backend can be slow (antivirus scan)
  return new Promise((resolve, reject) => {
    const tick = (n) => http.get({ host: "127.0.0.1", port: PORT, path: "/api/status", headers: { "x-rox-token": TOKEN } }, (r) => { r.resume(); resolve(); })
      .on("error", () => (n > 0 ? setTimeout(() => tick(n - 1), 250) : reject(new Error("backend did not start"))));
    tick(tries);
  });
}

async function createWindow() {
  win = new BrowserWindow({
    width: 1440, height: 900, minWidth: 900, minHeight: 600, backgroundColor: "#0b0b0c", title: "ROX AI Agent", show: false, icon: path.join(__dirname, "build", process.platform === "win32" ? "icon.ico" : "icon.png"),
    webPreferences: { preload: path.join(__dirname, "preload.js"), contextIsolation: true, nodeIntegration: false, sandbox: true,
      additionalArguments: [`--rox-token=${TOKEN}`, `--rox-port=${PORT}`] },
  });
  Menu.setApplicationMenu(null);
  win.once("ready-to-show", () => win.show());
  const dev = process.env.ROX_DEV_URL;
  try { await waitReady(); app.backendReady = true; } catch (e) {
    const logPath = path.join(app.getPath("userData"), "backend.log");
    dialog.showErrorBox("ROX — backend failed to start", `${backendOut.slice(-1800) || "No output from backend."}\n\nFull log: ${logPath}\nPort ${PORT} must be free (set ROX_PORT to change it).`);
  }
  if (dev) win.loadURL(dev); else win.loadFile(path.join(__dirname, "renderer", "index.html"));
}

ipcMain.on("toggle-fullscreen", () => win && win.setFullScreen(!win.isFullScreen()));
ipcMain.handle("pick-folder", async () => { const r = await dialog.showOpenDialog(win, { properties: ["openDirectory", "createDirectory"] }); return r.canceled ? null : r.filePaths[0]; });

app.whenReady().then(() => {
  startBackend(); createWindow();
  // Global emergency stop works even when a game has focus.
  globalShortcut.register("Control+Alt+Pause", () => post("/api/emergency-stop"));
  globalShortcut.register("Control+Alt+End", () => post("/api/emergency-stop"));
  // Quick command from anywhere in Windows: bring ROX to front and open the command bar.
  globalShortcut.register("Control+Shift+Space", () => { if (!win) return; if (win.isMinimized()) win.restore(); win.show(); win.focus(); win.webContents.send("open-command"); });
  globalShortcut.register("F11", () => win && win.setFullScreen(!win.isFullScreen()));
});
app.on("before-quit", () => { app.isQuitting = true; post("/api/emergency-stop"); setTimeout(() => backend && backend.kill(), 300); });
app.on("window-all-closed", () => app.quit());
