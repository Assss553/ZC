const { contextBridge, ipcRenderer } = require("electron");
const arg = (n) => (process.argv.find((a) => a.startsWith(`--${n}=`)) || "").split("=")[1];
contextBridge.exposeInMainWorld("rox", {
  token: arg("rox-token"), port: Number(arg("rox-port") || 8765),
  toggleFullscreen: () => ipcRenderer.send("toggle-fullscreen"),
  pickFolder: () => ipcRenderer.invoke("pick-folder"),
});
