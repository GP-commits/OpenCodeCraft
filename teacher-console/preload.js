const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("teacherConsole", {
  loadState: () => ipcRenderer.invoke("state:load"),
  saveState: (state) => ipcRenderer.invoke("state:save", state),
  exportReport: (state) => ipcRenderer.invoke("reports:export", state),
  exportBackup: (state) => ipcRenderer.invoke("backup:export", state),
  restoreBackup: () => ipcRenderer.invoke("backup:restore"),
  importStudents: () => ipcRenderer.invoke("students:import"),
  exportBridgeConfig: (state) => ipcRenderer.invoke("bridge:export-config", state)
});
