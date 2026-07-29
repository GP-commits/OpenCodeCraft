const { app, BrowserWindow, dialog, ipcMain } = require("electron");
const crypto = require("crypto");
const fs = require("fs/promises");
const http = require("http");
const path = require("path");

const defaultState = {
  schoolName: "My OpenClassCraft Classroom",
  profile: { teacherName: "Teacher", className: "Class 7A" },
  groups: ["Group A", "Group B"],
  assignments: [],
  bridge: { enabled: false, port: 31085, token: "", assignmentIndex: -1 },
  audit: [],
  unmatchedEvents: [],
  lessons: [
    { id: "water-lab", title: "Make Water", subject: "Chemistry", status: "Ready", objectives: "Combine elements and record observations.", checkpoints: ["Find the Chemistry Lab", "Create water", "Record your result"] },
    { id: "robot-route", title: "Robot Route", subject: "Coding", status: "Draft", objectives: "Use sequence and repeat blocks to guide a robot.", checkpoints: ["Place a robot", "Build a program", "Reach the flag"] }
  ],
  students: [
    { id: "student-001", name: "Aarav", group: "Group A", role: "Student" },
    { id: "student-002", name: "Maya", group: "Group A", role: "Student" },
    { id: "student-003", name: "Noah", group: "Group B", role: "Student" }
  ],
  progress: [
    { studentId: "student-001", lessonId: "water-lab", complete: 3, total: 3, note: "Completed independently" },
    { studentId: "student-002", lessonId: "water-lab", complete: 2, total: 3, note: "Needs observation note" },
    { studentId: "student-003", lessonId: "robot-route", complete: 1, total: 3, note: "Started program" }
  ]
};

let activeState;
let bridgeServer;

function statePath() { return path.join(app.getPath("userData"), "teacher-console.json"); }
async function readState() {
  try {
    const saved = JSON.parse(await fs.readFile(statePath(), "utf8"));
    return {
      ...structuredClone(defaultState),
      ...saved,
      profile: { ...defaultState.profile, ...(saved.profile || {}) },
      groups: Array.isArray(saved.groups) ? saved.groups : [...new Set((saved.students || []).map((student) => student.group).filter(Boolean))],
      assignments: Array.isArray(saved.assignments) ? saved.assignments : [],
      bridge: { ...defaultState.bridge, ...(saved.bridge || {}) },
      audit: Array.isArray(saved.audit) ? saved.audit : [],
      unmatchedEvents: Array.isArray(saved.unmatchedEvents) ? saved.unmatchedEvents : []
    };
  }
  catch { return structuredClone(defaultState); }
}
function bridgeLesson(state) {
  const bridge = state.bridge || defaultState.bridge;
  const assignment = state.assignments[bridge.assignmentIndex];
  const lesson = assignment && state.lessons.find((item) => item.id === assignment.lessonId);
  return {
    version: 1,
    active: Boolean(bridge.enabled && lesson),
    updatedAt: new Date().toISOString(),
    sessionCode: bridge.token.slice(0, 6).toUpperCase(),
    assignment: assignment ? { group: assignment.group, world: assignment.world } : null,
    lesson: lesson ? {
      title: lesson.title,
      goal: lesson.objectives,
      tasks: lesson.checkpoints.map((text) => ({ kind: "teacher", text }))
    } : null
  };
}
function ensureBridgeToken(state) {
  state.bridge = { ...defaultState.bridge, ...(state.bridge || {}) };
  if (!state.bridge.token) state.bridge.token = crypto.randomBytes(24).toString("hex");
}
function pushAudit(state, action, detail) {
  state.audit.unshift({ at: new Date().toISOString(), action, detail });
  state.audit = state.audit.slice(0, 250);
}
function applyProgressEvent(state, event) {
  if (!event || event.type !== "lesson_progress" || typeof event.playerName !== "string" || typeof event.lessonTitle !== "string") throw new Error("Invalid classroom event.");
  const student = state.students.find((item) => item.name.toLowerCase() === event.playerName.toLowerCase());
  const lesson = state.lessons.find((item) => item.title === event.lessonTitle);
  if (!student || !lesson) {
    state.unmatchedEvents.unshift({ at: new Date().toISOString(), playerName: event.playerName, lessonTitle: event.lessonTitle });
    state.unmatchedEvents = state.unmatchedEvents.slice(0, 100);
    pushAudit(state, "Unmatched LAN event", `${event.playerName}: ${event.lessonTitle}`);
    return false;
  }
  const total = Math.max(0, Math.min(100, Number(event.total) || lesson.checkpoints.length));
  const complete = Math.max(0, Math.min(total, Number(event.complete) || 0));
  let entry = state.progress.find((item) => item.studentId === student.id && item.lessonId === lesson.id);
  if (!entry) { entry = { studentId: student.id, lessonId: lesson.id, complete: 0, total, note: "" }; state.progress.push(entry); }
  entry.complete = complete; entry.total = total;
  pushAudit(state, "LAN checkpoint", `${student.name}: ${lesson.title} ${complete}/${total}`);
  return true;
}
async function stopBridge() {
  if (!bridgeServer) return;
  await new Promise((resolve) => bridgeServer.close(resolve));
  bridgeServer = undefined;
}
async function configureBridge(state) {
  activeState = state;
  ensureBridgeToken(activeState);
  if (!activeState.bridge.enabled) { await stopBridge(); return; }
  if (bridgeServer) return;
  bridgeServer = http.createServer((request, response) => {
    if (request.headers["x-openclasscraft-token"] !== activeState.bridge.token) {
      response.writeHead(403, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ error: "forbidden" }));
      return;
    }
    if (request.method === "GET" && request.url === "/session") {
      response.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" });
      response.end(JSON.stringify(bridgeLesson(activeState)));
      return;
    }
    if (request.method === "POST" && request.url === "/events") {
      let body = "";
      request.on("data", (chunk) => { body += chunk; if (body.length > 8192) request.destroy(); });
      request.on("end", async () => {
        try {
          const matched = applyProgressEvent(activeState, JSON.parse(body));
          await writeState(activeState);
          response.writeHead(200, { "Content-Type": "application/json" });
          response.end(JSON.stringify({ accepted: true, matched }));
        } catch (error) {
          response.writeHead(400, { "Content-Type": "application/json" });
          response.end(JSON.stringify({ error: error.message }));
        }
      });
      return;
    }
    response.writeHead(404, { "Content-Type": "application/json" });
    response.end(JSON.stringify({ error: "not_found" }));
  });
  await new Promise((resolve, reject) => {
    bridgeServer.once("error", reject);
    bridgeServer.listen(activeState.bridge.port, "127.0.0.1", resolve);
  });
}
async function writeState(state) {
  ensureBridgeToken(state);
  await fs.mkdir(path.dirname(statePath()), { recursive: true });
  await fs.writeFile(statePath(), JSON.stringify(state, null, 2));
  await configureBridge(state);
}
function isValidState(value) { return value && Array.isArray(value.lessons) && Array.isArray(value.students) && Array.isArray(value.progress); }
function parseCsv(text) {
  const lines = String(text).replace(/^\uFEFF/, "").split(/\r?\n/).filter((line) => line.trim());
  if (lines.length < 2) throw new Error("The CSV needs a header row and at least one student.");
  const parseLine = (line) => { const values = []; let value = ""; let quoted = false; for (let i = 0; i < line.length; i += 1) { const char = line[i]; if (char === '"' && line[i + 1] === '"') { value += '"'; i += 1; } else if (char === '"') quoted = !quoted; else if (char === "," && !quoted) { values.push(value.trim()); value = ""; } else value += char; } values.push(value.trim()); return values; };
  const headers = parseLine(lines[0]).map((header) => header.toLowerCase());
  const nameIndex = headers.findIndex((header) => ["name", "student", "student name"].includes(header));
  const groupIndex = headers.findIndex((header) => ["group", "class", "section"].includes(header));
  if (nameIndex < 0) throw new Error("The CSV must include a Name column.");
  return lines.slice(1).map(parseLine).map((row) => ({ name: row[nameIndex]?.trim(), group: groupIndex >= 0 ? row[groupIndex]?.trim() : "Ungrouped" })).filter((student) => student.name);
}
function csvField(value) { return `"${String(value ?? "").replaceAll('"', '""')}"`; }

function createWindow() {
  const window = new BrowserWindow({
    width: 1320, height: 840, minWidth: 1024, minHeight: 680,
    backgroundColor: "#edf4ef", title: "OpenClassCraft Teacher Console",
    webPreferences: { contextIsolation: true, nodeIntegration: false, preload: path.join(__dirname, "preload.js") }
  });
  window.loadFile(path.join(__dirname, "app", "index.html"));
}

app.whenReady().then(() => {
  createWindow();
  app.on("activate", () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});
app.on("window-all-closed", () => { if (process.platform !== "darwin") app.quit(); });

ipcMain.handle("state:load", async () => { const state = await readState(); ensureBridgeToken(state); activeState = state; await configureBridge(state); return state; });
ipcMain.handle("state:save", async (_event, state) => { await writeState(state); return true; });
ipcMain.handle("bridge:export-config", async (_event, state) => {
  ensureBridgeToken(state);
  const result = await dialog.showSaveDialog({ title: "Save LAN bridge settings", defaultPath: "openclasscraft-teacher-bridge.conf", filters: [{ name: "Luanti configuration", extensions: ["conf"] }] });
  if (result.canceled) return { canceled: true };
  const content = "# OpenClassCraft Teacher Console local LAN bridge\nsecure.http_mods = openclasscraft_classroom\nopenclasscraft_teacher_bridge_url = http://127.0.0.1:" + state.bridge.port + "/session\nopenclasscraft_teacher_events_url = http://127.0.0.1:" + state.bridge.port + "/events\nopenclasscraft_teacher_bridge_token = " + state.bridge.token + "\n";
  await fs.writeFile(result.filePath, content);
  return { canceled: false, path: result.filePath };
});
ipcMain.handle("students:import", async () => {
  const selection = await dialog.showOpenDialog({ title: "Import class list", properties: ["openFile"], filters: [{ name: "CSV", extensions: ["csv"] }] });
  if (selection.canceled) return { canceled: true };
  try { return { canceled: false, students: parseCsv(await fs.readFile(selection.filePaths[0], "utf8")) }; }
  catch (error) { return { canceled: false, error: error.message }; }
});
ipcMain.handle("backup:export", async (_event, state) => {
  const result = await dialog.showSaveDialog({ title: "Back up teacher workspace", defaultPath: "openclasscraft-teacher-backup.json", filters: [{ name: "OpenClassCraft backup", extensions: ["json"] }] });
  if (result.canceled) return { canceled: true };
  await fs.writeFile(result.filePath, JSON.stringify(state, null, 2));
  return { canceled: false, path: result.filePath };
});
ipcMain.handle("backup:restore", async () => {
  const result = await dialog.showOpenDialog({ title: "Restore teacher workspace", properties: ["openFile"], filters: [{ name: "OpenClassCraft backup", extensions: ["json"] }] });
  if (result.canceled) return { canceled: true };
  try {
    const restored = JSON.parse(await fs.readFile(result.filePaths[0], "utf8"));
    if (!isValidState(restored)) throw new Error("This is not an OpenClassCraft Teacher Console backup.");
    await writeState(restored);
    return { canceled: false, state: restored };
  } catch (error) { return { canceled: false, error: error.message }; }
});
ipcMain.handle("reports:export", async (_event, state) => {
  const result = await dialog.showSaveDialog({ title: "Export OpenClassCraft progress", defaultPath: "openclasscraft-progress.csv", filters: [{ name: "CSV", extensions: ["csv"] }] });
  if (result.canceled) return { canceled: true };
  const lessonName = new Map(state.lessons.map((lesson) => [lesson.id, lesson.title]));
  const studentName = new Map(state.students.map((student) => [student.id, student.name]));
  const rows = [["Student", "Lesson", "Completed checkpoints", "Total checkpoints", "Progress", "Teacher note"]];
  for (const entry of state.progress) rows.push([studentName.get(entry.studentId) || "Unknown", lessonName.get(entry.lessonId) || "Unknown", entry.complete, entry.total, `${entry.total ? Math.round((entry.complete / entry.total) * 100) : 0}%`, entry.note]);
  await fs.writeFile(result.filePath, rows.map((row) => row.map(csvField).join(",")).join("\n"));
  return { canceled: false, path: result.filePath };
});
