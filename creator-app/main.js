const { app, BrowserWindow, dialog, ipcMain } = require("electron");
const fs = require("fs/promises");
const path = require("path");

function createWindow() {
  const window = new BrowserWindow({
    width: 1440, height: 920, minWidth: 1080, minHeight: 700,
    backgroundColor: "#112537", title: "OpenClassCraft Creator",
    webPreferences: { contextIsolation: true, nodeIntegration: false, preload: path.join(__dirname, "preload.js") },
  });
  window.loadFile(path.join(__dirname, "app", "index.html"));
}
app.whenReady().then(() => { createWindow(); app.on("activate", () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); }); });
app.on("window-all-closed", () => { if (process.platform !== "darwin") app.quit(); });

function safeId(value) { return String(value || "classroom_project").toLowerCase().replace(/[^a-z0-9_]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 40) || "classroom_project"; }
ipcMain.handle("export-project", async (_event, project) => {
  const selection = await dialog.showOpenDialog({ title: "Choose where to save the OpenClassCraft mod", properties: ["openDirectory", "createDirectory"] });
  if (selection.canceled) return { canceled: true };
  const modDir = path.join(selection.filePaths[0], `openclasscraft_${safeId(project.name)}`);
  await fs.mkdir(modDir, { recursive: true });
  await fs.writeFile(path.join(modDir, "mod.conf"), `name = openclasscraft_${safeId(project.name)}\ndepends = default\n`);
  await fs.writeFile(path.join(modDir, "project.openclasscraft.json"), JSON.stringify(project, null, 2));
  await fs.writeFile(path.join(modDir, "init.lua"), project.generatedLua);
  return { canceled: false, path: modDir };
});
