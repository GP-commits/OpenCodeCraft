/* global Blockly */
const byId = (id) => document.getElementById(id);

Blockly.defineBlocksWithJsonArray([
  { type: "occ_when_placed", message0: "when this block is placed", nextStatement: null, colour: 165 },
  { type: "occ_when_player_near", message0: "when a player comes near", nextStatement: null, colour: 165 },
  { type: "occ_say", message0: "show message %1", args0: [{ type: "field_input", name: "TEXT", text: "Welcome to our lesson!" }], previousStatement: null, nextStatement: null, colour: 25 },
  { type: "occ_give_item", message0: "give item %1", args0: [{ type: "field_dropdown", name: "ITEM", options: [["chalkboard", "openclasscraft_classroom:chalkboard"], ["robot spawner", "openclasscraft_classroom:robot_spawner"], ["science lab", "openclasscraft_classroom:chemistry_lab"]] }], previousStatement: null, nextStatement: null, colour: 25 },
  { type: "occ_change_block", message0: "change this block to %1", args0: [{ type: "field_dropdown", name: "BLOCK", options: [["garden", "default:dirt_with_grass"], ["stone", "default:stone"], ["water", "default:water_source"]] }], previousStatement: null, nextStatement: null, colour: 25 },
  { type: "occ_wait", message0: "wait %1 seconds", args0: [{ type: "field_number", name: "SECONDS", value: 1, min: 0, max: 60, precision: 0.5 }], previousStatement: null, nextStatement: null, colour: 25 },
  { type: "occ_change_variable", message0: "change variable %1 by %2", args0: [{ type: "field_variable", name: "VAR", variable: "score" }, { type: "field_number", name: "CHANGE", value: 1, min: -1000, max: 1000 }], previousStatement: null, nextStatement: null, colour: 210 },
  { type: "occ_sensor_nearby", message0: "a player is nearby", output: "Boolean", colour: 280 },
]);

const workspace = Blockly.inject("blocklyDiv", {
  toolbox: byId("toolbox"),
  grid: { spacing: 20, length: 3, colour: "#cad8dc", snap: true },
  trashcan: true,
  zoom: { controls: true, wheel: true, startScale: 0.9, maxScale: 1.4, minScale: 0.55 },
  theme: Blockly.Themes.Classic,
});

function escapeLua(value) { return String(value).replace(/\\/g, "\\\\").replace(/\"/g, '\\"').replace(/\n/g, " "); }
function quote(value) { return `\"${escapeLua(value)}\"`; }
function indent(code) { return code.split("\n").filter(Boolean).map((line) => `  ${line}\n`).join(""); }
function identifier(value) { return String(value).toLowerCase().replace(/[^a-z0-9_]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 32) || "classroom_block"; }
function variableKey(block) {
  const model = workspace.getVariableById(block.getFieldValue("VAR"));
  return identifier(model ? model.name : "value");
}
function valueCode(block) {
  if (!block) return "0";
  if (block.type === "math_number") return String(Number(block.getFieldValue("NUM")) || 0);
  if (block.type === "text") return quote(block.getFieldValue("TEXT"));
  if (block.type === "variables_get") return `(tonumber(storage:get_string(name .. \":${variableKey(block)}\")) or 0)`;
  return "0";
}

function statementCode(block) {
  let code = "";
  for (let current = block; current; current = current.getNextBlock()) {
    if (current.type === "occ_say") code += `minetest.chat_send_player(name, ${quote(current.getFieldValue("TEXT"))})\n`;
    else if (current.type === "occ_give_item") code += `player:get_inventory():add_item(\"main\", ${quote(current.getFieldValue("ITEM"))})\n`;
    else if (current.type === "occ_change_block") code += `minetest.set_node(pos, {name = ${quote(current.getFieldValue("BLOCK"))}})\n`;
    else if (current.type === "occ_wait") code += `minetest.after(${Number(current.getFieldValue("SECONDS")) || 0}, function() end)\n`;
    else if (current.type === "variables_set") code += `storage:set_string(name .. \":${variableKey(current)}\", tostring(${valueCode(current.getInputTargetBlock("VALUE"))}))\n`;
    else if (current.type === "occ_change_variable") {
      const key = variableKey(current);
      const change = Number(current.getFieldValue("CHANGE")) || 0;
      code += `storage:set_string(name .. \":${key}\", tostring((tonumber(storage:get_string(name .. \":${key}\")) or 0) + ${change}))\n`;
    }
    else if (current.type === "controls_repeat_ext") {
      const inner = statementCode(current.getInputTargetBlock("DO"));
      code += `for _ = 1, ${Math.max(1, Number(current.getFieldValue("TIMES")) || 1)} do\n${indent(inner)}end\n`;
    } else if (current.type === "controls_if") {
      const inner = statementCode(current.getInputTargetBlock("DO0"));
      code += `if player and player:is_player() then\n${indent(inner)}end\n`;
    }
  }
  return code;
}

function generateLua() {
  const id = identifier(byId("projectName").value);
  const description = byId("blockName").value.trim() || "Classroom Block";
  const style = byId("blockStyle").value;
  const texture = `openclasscraft_creator_${style}.png`;
  let onPlace = "";
  let nearby = "";
  for (const block of workspace.getTopBlocks(true)) {
    if (block.type === "occ_when_placed") onPlace += statementCode(block.getNextBlock());
    if (block.type === "occ_when_player_near") nearby += statementCode(block.getNextBlock());
  }
  const interaction = onPlace ? `\non_rightclick = function(pos, node, clicker)\n  local player = clicker\n  local name = player:get_player_name()\n${indent(onPlace)}end,\n` : "";
  const nearBehavior = nearby ? `\nminetest.register_abm({\n  label = ${quote(`${description} nearby action`)},\n  nodenames = {\"openclasscraft_${id}:block\"},\n  interval = 1,\n  chance = 1,\n  action = function(pos)\n    for _, object in ipairs(minetest.get_objects_inside_radius(pos, 3)) do\n      if object:is_player() then\n        local player = object\n        local name = player:get_player_name()\n${indent(nearby)}        break\n      end\n    end\n  end,\n})\n` : "";
  return `-- Generated by OpenClassCraft Creator.\n-- This file only contains actions selected in the visual editor.\nlocal storage = minetest.get_mod_storage()\n\nminetest.register_node(\"openclasscraft_${id}:block\", {\n  description = ${quote(description)},\n  tiles = {${quote(texture)}},\n  groups = {crumbly = 2, classroom = 1},\n${interaction}})\n${nearBehavior}`;
}

function refreshPreview() {
  byId("previewLabel").textContent = byId("blockName").value || "Classroom Block";
  byId("previewBlock").className = `preview-block ${byId("blockStyle").value}`;
  byId("saveState").textContent = "Changes ready to export";
}

for (const id of ["projectName", "blockName", "blockStyle", "category"]) byId(id).addEventListener("input", refreshPreview);
workspace.addChangeListener(() => { byId("saveState").textContent = "Changes ready to export"; });
byId("resetButton").addEventListener("click", () => { workspace.clear(); byId("saveState").textContent = "New project"; });
byId("saveButton").addEventListener("click", async () => {
  const result = await window.creator.exportProject({
    name: byId("projectName").value,
    blockName: byId("blockName").value,
    style: byId("blockStyle").value,
    category: byId("category").value,
    workspace: Blockly.serialization.workspaces.save(workspace),
    generatedLua: generateLua(),
  });
  if (!result.canceled) byId("saveState").textContent = `Exported to ${result.path}`;
});
refreshPreview();
