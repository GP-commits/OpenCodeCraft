const { contextBridge, ipcRenderer } = require("electron");
contextBridge.exposeInMainWorld("creator", { exportProject: (project) => ipcRenderer.invoke("export-project", project) });
