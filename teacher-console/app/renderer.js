const byId = (id) => document.getElementById(id);
let state;
let currentView = "dashboard";
let editingLessonId = null;

function lessonById(id) { return state.lessons.find((lesson) => lesson.id === id); }
function studentById(id) { return state.students.find((student) => student.id === id); }
function percent(entry) { return entry.total ? Math.round((entry.complete / entry.total) * 100) : 0; }
function escapeHtml(value) { return String(value || "").replace(/[&<>"']/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[char]); }
function slug(value) { return String(value).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "") || `item-${Date.now()}`; }
function newId(prefix, label) { let id = `${prefix}-${slug(label)}`; let number = 2; while ([...state.lessons, ...state.students].some((item) => item.id === id)) id = `${prefix}-${slug(label)}-${number++}`; return id; }
function updateSaveState(message = "Unsaved changes") { byId("saveState").textContent = message; }
function action(label, key, tone = "secondary") { return `<button class="button compact ${tone}" data-action="${key}">${label}</button>`; }
function normaliseState() {
  state.profile = { teacherName: "Teacher", className: "Class", ...(state.profile || {}) };
  state.groups = Array.isArray(state.groups) ? state.groups : [...new Set(state.students.map((student) => student.group).filter(Boolean))];
  state.assignments = Array.isArray(state.assignments) ? state.assignments : [];
  state.bridge = { enabled: false, port: 31085, token: "", assignmentIndex: -1, ...(state.bridge || {}) };
}

function lessonCard(lesson) {
  const draft = lesson.status === "Draft" ? "draft" : "";
  return `<article class="card"><span class="eyebrow">${escapeHtml(lesson.subject)}</span><h3>${escapeHtml(lesson.title)}</h3><p>${escapeHtml(lesson.objectives || "No objective added yet.")}</p><div class="card-footer"><span class="status ${draft}">${escapeHtml(lesson.status)}</span><div class="card-actions">${action("Edit", `edit-lesson:${lesson.id}`)}${action("Delete", `delete-lesson:${lesson.id}`, "danger")}</div></div></article>`;
}
function renderDashboard() {
  const complete = state.progress.filter((entry) => entry.total > 0 && entry.complete >= entry.total).length;
  byId("dashboard").innerHTML = `<div class="metrics"><article class="metric"><span class="eyebrow">Students</span><strong>${state.students.length}</strong><span>in this local classroom</span></article><article class="metric"><span class="eyebrow">Lessons</span><strong>${state.lessons.length}</strong><span>ready or in draft</span></article><article class="metric"><span class="eyebrow">Completed activities</span><strong>${complete}</strong><span>tracked records</span></article></div><div class="section-heading"><div><h2>Continue planning</h2><p>${escapeHtml(state.schoolName || "My OpenClassCraft Classroom")}</p></div></div><div class="cards">${state.lessons.slice(0, 3).map(lessonCard).join("")}</div>`;
}
function renderLessons() { byId("lessons").innerHTML = `<div class="section-heading"><div><h2>Lesson library</h2><p>Prepare goals and checkpoints before placing guides, boards, flags, and activities in a world.</p></div></div><div class="cards">${state.lessons.length ? state.lessons.map(lessonCard).join("") : "<p>No lessons yet. Create your first lesson.</p>"}</div>`; }
function renderClassroom() {
  const assignments = state.assignments.map((assignment, index) => `<tr><td>${escapeHtml(assignment.group)}</td><td>${escapeHtml(lessonById(assignment.lessonId)?.title || "Missing lesson")}</td><td>${escapeHtml(assignment.world || "No world selected")}</td><td><div class="row-actions">${action("Remove", `delete-assignment:${index}`, "danger")}</div></td></tr>`).join("");
  const selected = state.assignments[state.bridge.assignmentIndex];
  const selectedTitle = selected ? lessonById(selected.lessonId)?.title || "Missing lesson" : "No lesson selected";
  const bridgeStatus = state.bridge.enabled ? "Active on this computer" : "Not active";
  byId("classroom").innerHTML = `<div class="metrics"><article class="metric"><span class="eyebrow">School</span><strong>${escapeHtml(state.schoolName)}</strong><span>${escapeHtml(state.profile.teacherName)} · ${escapeHtml(state.profile.className)}</span></article><article class="metric"><span class="eyebrow">Groups</span><strong>${state.groups.length}</strong><span>${state.groups.map(escapeHtml).join(", ") || "No groups"}</span></article><article class="metric"><span class="eyebrow">LAN bridge</span><strong>${escapeHtml(bridgeStatus)}</strong><span>${escapeHtml(selectedTitle)}</span></article></div><div class="section-heading"><div><h2>Classroom setup</h2><p>Set up this local class before hosting a LAN world.</p></div><div class="row-actions">${action("Edit profile", "edit-profile")}${action("Add group", "add-group")}${action("Assign lesson", "add-assignment", "primary")}</div></div><table><thead><tr><th>Group</th><th>Lesson</th><th>Starter world</th><th></th></tr></thead><tbody>${assignments || "<tr><td colspan=\"4\">No assignments yet.</td></tr>"}</tbody></table><div class="section-heading"><div><h2>LAN lesson bridge</h2><p>Shares only the selected lesson plan with a local OpenClassCraft host. It never uploads student records.</p></div><div class="row-actions">${action("Choose lesson", "choose-bridge")}${action("Export settings", "export-bridge")}${action(state.bridge.enabled ? "Stop bridge" : "Start bridge", "toggle-bridge", state.bridge.enabled ? "danger" : "primary")}</div></div>`;
}
function renderStudents() {
  byId("students").innerHTML = `<div class="section-heading"><div><h2>Students</h2><p>Maintain a local class list and groups.</p></div><div class="row-actions"><button class="button secondary" data-action="import-students">Import CSV</button><button class="button primary" data-action="add-student">Add student</button></div></div><table><thead><tr><th>Name</th><th>Group</th><th>Role</th><th></th></tr></thead><tbody>${state.students.map((student) => `<tr><td>${escapeHtml(student.name)}</td><td>${escapeHtml(student.group)}</td><td>${escapeHtml(student.role)}</td><td><div class="row-actions">${action("Edit", `edit-student:${student.id}`)}${action("Remove", `delete-student:${student.id}`, "danger")}</div></td></tr>`).join("")}</tbody></table>`;
}
function renderReports() {
  const rows = state.progress.map((entry, index) => `<tr><td>${escapeHtml(studentById(entry.studentId)?.name || "Unknown")}</td><td>${escapeHtml(lessonById(entry.lessonId)?.title || "Unknown")}</td><td><div class="progress-control">${action("-", `progress:${index}:-1`)}<div class="progress-bar"><span style="width:${percent(entry)}%"></span></div><span>${entry.complete}/${entry.total}</span>${action("+", `progress:${index}:1`)}</div></td><td>${escapeHtml(entry.note || "-")}</td><td><div class="row-actions">${action("Note", `note:${index}`)}${action("Remove", `delete-progress:${index}`, "danger")}</div></td></tr>`).join("");
  byId("reports").innerHTML = `<div class="section-heading"><div><h2>Learning progress</h2><p>Update checkpoints during a class, then export a CSV record.</p></div><div class="row-actions"><button class="button secondary" data-action="add-progress">Add record</button><button id="exportButton" class="button primary">Export CSV</button></div></div><table><thead><tr><th>Student</th><th>Lesson</th><th>Progress</th><th>Teacher note</th><th></th></tr></thead><tbody>${rows || "<tr><td colspan=\"5\">No progress records yet.</td></tr>"}</tbody></table>`;
  byId("exportButton").addEventListener("click", exportReport);
}
function render() { renderDashboard(); renderClassroom(); renderLessons(); renderStudents(); renderReports(); bindActions(); }
function showView(view) {
  currentView = view;
  document.querySelectorAll(".view").forEach((element) => element.classList.toggle("active", element.id === view));
  document.querySelectorAll(".nav-item").forEach((element) => element.classList.toggle("active", element.dataset.view === view));
  byId("pageTitle").textContent = view[0].toUpperCase() + view.slice(1);
  byId("newButton").style.display = view === "reports" || view === "classroom" ? "none" : "inline-block";
  byId("newButton").textContent = view === "students" ? "New student" : "New lesson";
}
async function save() { await window.teacherConsole.saveState(state); updateSaveState(`Saved locally at ${new Date().toLocaleTimeString()}`); }
async function exportReport() { const result = await window.teacherConsole.exportReport(state); if (!result.canceled) updateSaveState(`Exported ${result.path}`); }
function openLessonDialog(lesson = null) {
  editingLessonId = lesson?.id || null;
  byId("lessonDialogTitle").textContent = lesson ? "Edit lesson" : "New lesson";
  byId("lessonTitle").value = lesson?.title || "";
  byId("lessonSubject").value = lesson?.subject || "Coding";
  byId("lessonObjectives").value = lesson?.objectives || "";
  byId("lessonCheckpoints").value = (lesson?.checkpoints || []).join("\n");
  byId("lessonDialog").showModal();
}
function editStudent(student = null) {
  const name = prompt("Student name", student?.name || ""); if (name === null || !name.trim()) return;
  const group = prompt("Group", student?.group || ""); if (group === null) return;
  const groupName = group.trim() || "Ungrouped";
  if (!state.groups.includes(groupName)) state.groups.push(groupName);
  if (student) { student.name = name.trim(); student.group = groupName; }
  else state.students.push({ id: newId("student", name), name: name.trim(), group: groupName, role: "Student" });
  updateSaveState(); render(); showView("students");
}
function addProgress() {
  if (!state.students.length || !state.lessons.length) return alert("Add at least one student and lesson first.");
  const name = prompt(`Student name:\n${state.students.map((student) => student.name).join("\n")}`); if (!name) return;
  const student = state.students.find((item) => item.name.toLowerCase() === name.trim().toLowerCase()); if (!student) return alert("Choose a listed student name.");
  const title = prompt(`Lesson title:\n${state.lessons.map((lesson) => lesson.title).join("\n")}`); if (!title) return;
  const lesson = state.lessons.find((item) => item.title.toLowerCase() === title.trim().toLowerCase()); if (!lesson) return alert("Choose a listed lesson title.");
  state.progress.push({ studentId: student.id, lessonId: lesson.id, complete: 0, total: lesson.checkpoints.length, note: "" }); updateSaveState(); render(); showView("reports");
}
function bindActions() {
  document.querySelectorAll("[data-action]").forEach((button) => button.addEventListener("click", () => {
    const [kind, value, delta] = button.dataset.action.split(":");
    if (kind === "edit-lesson") openLessonDialog(lessonById(value));
    if (kind === "delete-lesson" && confirm("Delete this lesson and related progress records?")) { state.lessons = state.lessons.filter((lesson) => lesson.id !== value); state.progress = state.progress.filter((entry) => entry.lessonId !== value); updateSaveState(); render(); }
    if (kind === "add-student") editStudent();
    if (kind === "import-students") importStudents();
    if (kind === "edit-student") editStudent(studentById(value));
    if (kind === "delete-student" && confirm("Remove this student and related progress records?")) { state.students = state.students.filter((student) => student.id !== value); state.progress = state.progress.filter((entry) => entry.studentId !== value); updateSaveState(); render(); }
    if (kind === "progress") { const entry = state.progress[Number(value)]; entry.complete = Math.max(0, Math.min(entry.total, entry.complete + Number(delta))); updateSaveState(); render(); showView("reports"); }
    if (kind === "note") { const entry = state.progress[Number(value)]; const note = prompt("Teacher note", entry.note || ""); if (note !== null) { entry.note = note.trim(); updateSaveState(); render(); showView("reports"); } }
    if (kind === "delete-progress" && confirm("Remove this progress record?")) { state.progress.splice(Number(value), 1); updateSaveState(); render(); showView("reports"); }
    if (kind === "add-progress") addProgress();
    if (kind === "edit-profile") editProfile();
    if (kind === "add-group") addGroup();
    if (kind === "add-assignment") addAssignment();
    if (kind === "delete-assignment") { state.assignments.splice(Number(value), 1); updateSaveState(); render(); showView("classroom"); }
    if (kind === "choose-bridge") chooseBridgeAssignment();
    if (kind === "toggle-bridge") toggleBridge();
    if (kind === "export-bridge") exportBridge();
  }));
}
function editProfile() {
  const school = prompt("School name", state.schoolName); if (school === null || !school.trim()) return;
  const teacher = prompt("Teacher name", state.profile.teacherName); if (teacher === null || !teacher.trim()) return;
  const className = prompt("Class name", state.profile.className); if (className === null || !className.trim()) return;
  state.schoolName = school.trim(); state.profile = { teacherName: teacher.trim(), className: className.trim() }; updateSaveState(); render(); showView("classroom");
}
function addGroup() { const group = prompt("New group name"); if (!group || !group.trim()) return; if (!state.groups.includes(group.trim())) state.groups.push(group.trim()); updateSaveState(); render(); showView("classroom"); }
function addAssignment() {
  if (!state.groups.length || !state.lessons.length) return alert("Add at least one group and lesson first.");
  const group = prompt(`Group:\n${state.groups.join("\n")}`); if (!group || !state.groups.includes(group.trim())) return alert("Choose a listed group.");
  const lessonTitle = prompt(`Lesson:\n${state.lessons.map((lesson) => lesson.title).join("\n")}`); if (!lessonTitle) return;
  const lesson = state.lessons.find((item) => item.title.toLowerCase() === lessonTitle.trim().toLowerCase()); if (!lesson) return alert("Choose a listed lesson.");
  const world = prompt("Starter world name", lesson.title) || lesson.title;
  state.assignments.push({ group: group.trim(), lessonId: lesson.id, world: world.trim() }); updateSaveState(); render(); showView("classroom");
}
function chooseBridgeAssignment() {
  if (!state.assignments.length) return alert("Create a lesson assignment first.");
  const choices = state.assignments.map((assignment, index) => `${index + 1}. ${assignment.group} - ${lessonById(assignment.lessonId)?.title || "Missing lesson"}`);
  const choice = Number(prompt(`Choose the LAN lesson:\n${choices.join("\n")}`, String((state.bridge.assignmentIndex || 0) + 1)));
  if (!Number.isInteger(choice) || choice < 1 || choice > state.assignments.length) return;
  state.bridge.assignmentIndex = choice - 1; updateSaveState(); render(); showView("classroom");
}
async function toggleBridge() {
  if (!state.bridge.enabled && (state.bridge.assignmentIndex < 0 || !state.assignments[state.bridge.assignmentIndex])) return alert("Choose a lesson assignment first.");
  state.bridge.enabled = !state.bridge.enabled; await save(); render(); showView("classroom");
}
async function exportBridge() { const result = await window.teacherConsole.exportBridgeConfig(state); if (!result.canceled) updateSaveState(`Bridge settings saved to ${result.path}`); }
async function importStudents() {
  const result = await window.teacherConsole.importStudents();
  if (result.error) return alert(result.error);
  if (result.canceled) return;
  let imported = 0;
  for (const entry of result.students) {
    const group = entry.group || "Ungrouped";
    if (!state.groups.includes(group)) state.groups.push(group);
    const existing = state.students.find((student) => student.name.toLowerCase() === entry.name.toLowerCase());
    if (existing) { existing.group = group; } else { state.students.push({ id: newId("student", entry.name), name: entry.name, group, role: "Student" }); imported += 1; }
  }
  updateSaveState(`${imported} students imported`); render(); showView("students"); await save();
}

document.querySelectorAll(".nav-item").forEach((button) => button.addEventListener("click", () => showView(button.dataset.view)));
byId("saveButton").addEventListener("click", save);
byId("newButton").addEventListener("click", () => currentView === "students" ? editStudent() : openLessonDialog());
byId("backupButton").addEventListener("click", async () => { const result = await window.teacherConsole.exportBackup(state); if (!result.canceled) updateSaveState(`Backup saved to ${result.path}`); });
byId("restoreButton").addEventListener("click", async () => { if (!confirm("Restore a backup? Current unsaved changes will be replaced.")) return; const result = await window.teacherConsole.restoreBackup(); if (result.error) return alert(result.error); if (!result.canceled) { state = result.state; normaliseState(); render(); showView(currentView); updateSaveState("Backup restored locally"); } });
byId("createLesson").addEventListener("click", async (event) => {
  event.preventDefault(); const title = byId("lessonTitle").value.trim(); if (!title) return;
  const details = { title, subject: byId("lessonSubject").value, status: "Draft", objectives: byId("lessonObjectives").value.trim(), checkpoints: byId("lessonCheckpoints").value.split("\n").map((value) => value.trim()).filter(Boolean) };
  if (editingLessonId) Object.assign(lessonById(editingLessonId), details); else state.lessons.push({ id: newId("lesson", title), ...details });
  byId("lessonDialog").close(); updateSaveState(); render(); showView("lessons"); await save();
});
(async () => { state = await window.teacherConsole.loadState(); normaliseState(); render(); showView(currentView); })();
