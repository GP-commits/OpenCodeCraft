local S = minetest.get_translator("openclasscraft_creator")
local storage = minetest.get_mod_storage()

local styles = {
	grass = {label = "Garden", node = "openclasscraft_creator:block_grass", texture = "openclasscraft_creator_garden.png"},
	stone = {label = "Stone", node = "openclasscraft_creator:block_stone", texture = "openclasscraft_creator_stone.png"},
	wood = {label = "Wood", node = "openclasscraft_creator:block_wood", texture = "openclasscraft_creator_wood.png"},
	glass = {label = "Glass", node = "openclasscraft_creator:block_glass", texture = "openclasscraft_creator_glass.png^[opacity:165"},
}

local style_order = {"grass", "stone", "wood", "glass"}
local sessions = {}
local world_edit_selections = {}

local function trim(value)
	return (value or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function get_project(player_name)
	local raw = storage:get_string("project:" .. player_name)
	local project = raw ~= "" and minetest.deserialize(raw) or nil
	if type(project) ~= "table" then
		project = {name = "My Learning Block", style = "grass", message = "Hello, explorer!", script = {"say"}}
	end
	project.style = styles[project.style] and project.style or "grass"
	project.script = type(project.script) == "table" and project.script or {"say"}
	return project
end

local function save_project(player_name, project)
	storage:set_string("project:" .. player_name, minetest.serialize(project))
end

local function project_for(player)
	local player_name = player:get_player_name()
	sessions[player_name] = sessions[player_name] or get_project(player_name)
	return sessions[player_name]
end

local function script_label(action)
	local labels = {
		say = "Say message",
		wait = "Wait 1 second",
		give_apple = "Give an apple",
	}
	return labels[action] or action
end

local function show_creator(player)
	local project = project_for(player)
	local script_lines = {}
	for index, action in ipairs(project.script) do
		script_lines[index] = index .. ". " .. script_label(action)
	end
	local style_index = 1
	for index, style in ipairs(style_order) do
		if style == project.style then
			style_index = index
			break
		end
	end
	local preview = styles[project.style].node
	local fs = table.concat({
		"formspec_version[4]size[14,9]",
		"bgcolor[#17212b;true]",
		"label[0.6,0.45;OpenClassCraft Creator Lab]",
		"label[0.6,0.85;Build a safe mini-mod with visual blocks. No Lua is used.]",
		"box[0.45,1.25;4.35,7.2;#243646]",
		"label[0.75,1.55;1. Design your custom block]",
		"field[0.75,2.1;3.65,0.7;block_name;Block name;", minetest.formspec_escape(project.name), "]",
		"dropdown[0.75,2.95;3.65,0.7;style;Grass,Stone,Wood,Glass;", style_index, "]",
		"textarea[0.75,3.65;3.65,2.0;message;Message to say;", minetest.formspec_escape(project.message), "]",
		"button[0.75,6.05;3.65,0.75;save;Save project]",
		"button[0.75,7.0;3.65,0.75;create;Get custom block]",
		"box[5.05,1.25;5.35,7.2;#243646]",
		"label[5.35,1.55;2. Visual program]",
		"label[5.35,1.9;When a player right-clicks this block:]",
		"textlist[5.35,2.3;4.75,3.45;script;", minetest.formspec_escape(table.concat(script_lines, ",")), ";1;false]",
		"button[5.35,6.05;1.45,0.7;add_say;+ Say]",
		"button[6.95,6.05;1.45,0.7;add_wait;+ Wait]",
		"button[8.55,6.05;1.2,0.7;add_gift;+ Gift]",
		"button[5.35,6.95;1.45,0.7;move_up;Up]",
		"button[6.95,6.95;1.45,0.7;move_down;Down]",
		"button[8.55,6.95;1.2,0.7;remove;Remove]",
		"label[5.35,7.95;Click actions to build the order. Drag-and-drop workspace comes next.]",
		"box[10.65,1.25;2.9,7.2;#243646]",
		"label[10.95,1.55;Preview]",
		"item_image[11.6,2.0;1.4,1.4;", preview, "]",
		"label[10.95,3.75;Right-click your placed\nblock to run its program.]",
		"button_exit[10.95,7.35;2.1,0.75;close;Done]",
	})
	minetest.show_formspec(player:get_player_name(), "openclasscraft_creator:lab", fs)
end

local function selected_index(fields, project)
	if not fields.script then
		return #project.script
	end
	local event = minetest.explode_textlist_event(fields.script)
	return event.index > 0 and event.index or #project.script
end

local function give_project_block(player, project)
	local style = styles[project.style]
	local stack = ItemStack(style.node)
	local meta = stack:get_meta()
	meta:set_string("creator_name", project.name)
	meta:set_string("creator_message", project.message)
	meta:set_string("creator_script", minetest.serialize(project.script))
	meta:set_string("description", project.name .. "\nCreator Lab block")
	local inventory = player:get_inventory()
	if inventory:room_for_item("main", stack) then
		inventory:add_item("main", stack)
		minetest.chat_send_player(player:get_player_name(), "[Creator Lab] Your custom block is in your inventory.")
	else
		minetest.add_item(vector.offset(player:get_pos(), 0, 1, 0), stack)
		minetest.chat_send_player(player:get_player_name(), "[Creator Lab] Your inventory is full, so the block was dropped nearby.")
	end
end

local function run_block_program(pos, player)
	local meta = minetest.get_meta(pos)
	local script = minetest.deserialize(meta:get_string("creator_script")) or {"say"}
	local message = meta:get_string("creator_message")
	local block_name = meta:get_string("creator_name")
	local delay = 0
	for _, action in ipairs(script) do
		if action == "wait" then
			delay = delay + 1
		elseif action == "say" then
			minetest.after(delay, function()
				minetest.chat_send_player(player:get_player_name(), "[" .. (block_name ~= "" and block_name or "Creator Block") .. "] " .. message)
			end)
		elseif action == "give_apple" then
			minetest.after(delay, function()
				local stack = ItemStack("default:apple")
				if player:get_inventory():room_for_item("main", stack) then
					player:get_inventory():add_item("main", stack)
				else
					minetest.add_item(vector.offset(player:get_pos(), 0, 1, 0), stack)
				end
			end)
		end
	end
end

local function place_project_block(itemstack, placer, pointed_thing)
	-- item_place may consume the stack, so keep the project payload before it runs.
	local item_meta = itemstack:get_meta()
	local project_payload = {
		name = item_meta:get_string("creator_name"),
		message = item_meta:get_string("creator_message"),
		script = item_meta:get_string("creator_script"),
	}
	local result = minetest.item_place(itemstack, placer, pointed_thing)
	if pointed_thing.type ~= "node" then
		return result
	end
	local pos = pointed_thing.above
	if minetest.get_node(pos).name ~= itemstack:get_name() then
		return result
	end
	local node_meta = minetest.get_meta(pos)
	node_meta:set_string("creator_name", project_payload.name)
	node_meta:set_string("creator_message", project_payload.message)
	node_meta:set_string("creator_script", project_payload.script)
	node_meta:set_string("owner", placer and placer:get_player_name() or "")
	node_meta:set_string("infotext", project_payload.name)
	return result
end

local function texture_name(tile)
	if type(tile) == "string" then
		return tile
	end
	if type(tile) == "table" then
		return tile.name
	end
	return nil
end

-- Use each node's actual world faces for its inventory icon. This keeps the
-- catalog honest: a block icon now looks like the block that is placed.
minetest.register_on_mods_loaded(function()
	local solid_tiles = {
		["default:sandstone"] = "openclasscraft_sandstone.png",
		["default:sandstonebrick"] = "openclasscraft_sandstone_brick.png",
		["default:sandstone_block"] = "openclasscraft_sandstone_block.png",
		["default:desert_sandstone"] = "openclasscraft_desert_sandstone.png",
		["default:desert_sandstone_brick"] = "openclasscraft_desert_sandstone_brick.png",
		["default:desert_sandstone_block"] = "openclasscraft_desert_sandstone_block.png",
		["default:desert_cobble"] = "openclasscraft_desert_cobble.png",
		["default:mossycobble"] = "openclasscraft_mossycobble.png",
		["default:brick"] = "openclasscraft_brick.png",
		["default:steelblock"] = "openclasscraft_steelblock.png",
		["default:stonebrick"] = "openclasscraft_stonebrick.png",
		["default:obsidian"] = "openclasscraft_obsidian.png",
		["default:obsidianbrick"] = "openclasscraft_obsidian_brick.png",
		["default:obsidian_block"] = "openclasscraft_obsidian_block.png",
		["default:wood"] = "openclasscraft_wood.png",
		["default:junglewood"] = "openclasscraft_junglewood.png",
		["default:pine_wood"] = "openclasscraft_pine_wood.png",
		["default:acacia_wood"] = "openclasscraft_acacia_wood.png",
		["default:aspen_wood"] = "openclasscraft_aspen_wood.png",
		["default:stone_with_coal"] = "openclasscraft_ore_coal.png",
		["default:stone_with_iron"] = "openclasscraft_ore_iron.png",
		["default:stone_with_copper"] = "openclasscraft_ore_copper.png",
		["default:stone_with_tin"] = "openclasscraft_ore_tin.png",
		["default:stone_with_gold"] = "openclasscraft_ore_gold.png",
		["default:stone_with_mese"] = "openclasscraft_ore_mese.png",
		["default:stone_with_diamond"] = "openclasscraft_ore_diamond.png",
		["default:coral_skeleton"] = "openclasscraft_coral_skeleton.png",
	}
	for name, texture in pairs(solid_tiles) do
		if minetest.registered_nodes[name] then
			minetest.override_item(name, {tiles = {texture}})
		end
	end

	if minetest.registered_nodes["default:cactus"] then
		minetest.override_item("default:cactus", {
			tiles = {"openclasscraft_cactus_top.png", "openclasscraft_cactus_top.png", "openclasscraft_cactus_side.png"},
		})
	end

	local plant_textures = {
		["default:sapling"] = "openclasscraft_sapling_alpha.png",
		["default:junglesapling"] = "openclasscraft_junglesapling_alpha.png",
		["default:emergent_jungle_sapling"] = "openclasscraft_junglesapling_alpha.png",
		["default:pine_sapling"] = "openclasscraft_pine_sapling_alpha.png",
		["default:acacia_sapling"] = "openclasscraft_acacia_sapling_alpha.png",
		["default:aspen_sapling"] = "openclasscraft_aspen_sapling_alpha.png",
		["default:junglegrass"] = "openclasscraft_junglegrass_sprite_alpha.png",
		["default:fern_1"] = "openclasscraft_fern_sprite_alpha.png",
	}
	for index = 1, 5 do
		plant_textures["default:grass_" .. index] = "openclasscraft_grass_sprite_alpha.png"
		plant_textures["default:dry_grass_" .. index] = "openclasscraft_dry_grass_sprite_alpha.png"
	end
	for index = 2, 3 do
		plant_textures["default:fern_" .. index] = "openclasscraft_fern_sprite_alpha.png"
	end
	for name, texture in pairs(plant_textures) do
		if minetest.registered_nodes[name] then
			minetest.override_item(name, {
				tiles = {texture},
				inventory_image = texture,
				wield_image = texture,
			})
		end
	end

	local coral_textures = {
		["default:coral_green"] = "openclasscraft_coral_green_alpha.png",
		["default:coral_pink"] = "openclasscraft_coral_pink_alpha.png",
		["default:coral_cyan"] = "openclasscraft_coral_cyan_alpha.png",
		["default:coral_orange"] = "openclasscraft_coral_orange_alpha.png",
		["default:coral_brown"] = "openclasscraft_coral_brown_alpha.png",
	}
	for name, texture in pairs(coral_textures) do
		if minetest.registered_nodes[name] then
			minetest.override_item(name, {
				tiles = {texture},
				special_tiles = {{name = texture, tileable_vertical = true}},
				inventory_image = texture,
				wield_image = texture,
			})
		end
	end

	local torch_texture = {
		name = "openclasscraft_torch_animated.png",
		animation = {type = "vertical_frames", aspect_w = 1, aspect_h = 1, length = 0.8},
	}
	for _, name in ipairs({"default:torch", "default:torch_wall", "default:torch_ceiling"}) do
		if minetest.registered_nodes[name] then
			minetest.override_item(name, {
				tiles = {torch_texture},
				inventory_image = "openclasscraft_torch_frame_1_alpha.png",
				wield_image = "openclasscraft_torch_frame_1_alpha.png",
			})
		end
	end

	-- Keep unrelated world textures unchanged. Only OpenClassCraft's Chemistry
	-- Lab receives this dedicated classroom material set.
	if minetest.registered_nodes["openclasscraft_classroom:chemistry_lab"] then
		minetest.override_item("openclasscraft_classroom:chemistry_lab", {
			tiles = {
				"openclasscraft_metal.png", "openclasscraft_metal.png",
				"openclasscraft_tech.png", "openclasscraft_tech.png",
				"openclasscraft_chemistry.png", "openclasscraft_chemistry.png",
			},
		})
	end
	if minetest.registered_nodes["openclasscraft_classroom:chalkboard"] then
		minetest.override_item("openclasscraft_classroom:chalkboard", {
			inventory_image = "openclasscraft_board.png^[colorize:#071018:130",
		})
	end

	local item_icons = {
		["openclasscraft_classroom:hydrogen_atom"] = "openclasscraft_icon_hydrogen_atom_alpha.png",
		["openclasscraft_classroom:oxygen_atom"] = "openclasscraft_icon_oxygen_atom_alpha.png",
		["openclasscraft_classroom:carbon_atom"] = "openclasscraft_icon_carbon_atom_alpha.png",
		["openclasscraft_classroom:nitrogen_atom"] = "openclasscraft_icon_nitrogen_atom_alpha.png",
		["openclasscraft_classroom:sodium_atom"] = "openclasscraft_icon_sodium_atom_alpha.png",
		["openclasscraft_classroom:chlorine_atom"] = "openclasscraft_icon_chlorine_atom_alpha.png",
		["openclasscraft_classroom:water_molecule"] = "openclasscraft_icon_water_molecule_alpha.png",
		["openclasscraft_classroom:oxygen_molecule"] = "openclasscraft_icon_oxygen_molecule_alpha.png",
		["openclasscraft_classroom:hydrogen_molecule"] = "openclasscraft_icon_hydrogen_molecule_alpha.png",
		["openclasscraft_classroom:carbon_dioxide"] = "openclasscraft_icon_carbon_dioxide_alpha.png",
		["openclasscraft_classroom:sodium_chloride"] = "openclasscraft_icon_sodium_chloride_alpha.png",
		["openclasscraft_classroom:ammonia"] = "openclasscraft_icon_ammonia_alpha.png",
		["openclasscraft_classroom:methane"] = "openclasscraft_icon_methane_alpha.png",
		["openclasscraft_classroom:lesson_planner"] = "openclasscraft_icon_lesson_planner_alpha.png",
		["openclasscraft_creator:lab"] = "openclasscraft_icon_creator_lab_alpha.png",
	}
	for name, image in pairs(item_icons) do
		if minetest.registered_items[name] then
			minetest.override_item(name, {inventory_image = image})
		end
	end

	for name, definition in pairs(minetest.registered_nodes) do
		local groups = definition.groups or {}
		local tiles = definition.tiles
		if name ~= "air" and groups.not_in_creative_inventory ~= 1 and
			not definition.inventory_image and type(tiles) == "table" then
			local top = texture_name(tiles[1])
			local front = texture_name(tiles[5]) or texture_name(tiles[6]) or texture_name(tiles[3]) or top
			local side = texture_name(tiles[4]) or texture_name(tiles[2]) or top
			if top and front and side then
				minetest.override_item(name, {
					inventory_image = minetest.inventorycube(top, front, side),
				})
			end
		end
	end
end)

for style_name, style in pairs(styles) do
	minetest.register_node(style.node, {
		description = "Creator Block (" .. style.label .. ")",
		tiles = {style.texture},
		groups = {crumbly = 2, oddly_breakable_by_hand = 2},
		is_ground_content = false,
		on_place = place_project_block,
		on_rightclick = function(pos, node, clicker)
			run_block_program(pos, clicker)
		end,
	})
end

minetest.register_craftitem("openclasscraft_creator:lab", {
	description = "Creator Lab\nBuild blocks with visual programming",
	inventory_image = "default_book.png^[colorize:#28b6f6:100",
	groups = {classroom = 1},
	on_use = function(itemstack, user)
		show_creator(user)
		return itemstack
	end,
})

local function world_edit_marker(player, message)
	minetest.chat_send_player(player:get_player_name(), "[World Edit] " .. message)
end

local function selected_node_pos(pointed_thing)
	if not pointed_thing or pointed_thing.type ~= "node" then
		return nil
	end
	return vector.round(pointed_thing.under)
end

local function remove_entities_in_flat_area(minp, maxp)
	local center = vector.new((minp.x + maxp.x) / 2, minp.y + 4, (minp.z + maxp.z) / 2)
	local radius = math.max(maxp.x - minp.x, maxp.z - minp.z) / 2 + 8
	local removed = 0
	for _, object in ipairs(minetest.get_objects_inside_radius(center, radius)) do
		if not object:is_player() then
			local pos = object:get_pos()
			if pos and pos.x >= minp.x and pos.x <= maxp.x and
					pos.z >= minp.z and pos.z <= maxp.z and
					pos.y >= minp.y - 2 and pos.y <= minp.y + 12 then
				object:remove()
				removed = removed + 1
			end
		end
	end
	return removed
end

local function clear_world_edit_area(player)
	local name = player:get_player_name()
	local selection = world_edit_selections[name]
	if not selection or not selection.pos1 or not selection.pos2 then
		world_edit_marker(player, "Select two corners first: left-click corner 1, then left-click corner 2.")
		return
	end

	local pos1 = selection.pos1
	local pos2 = selection.pos2
	local minp = {
		x = math.min(pos1.x, pos2.x),
		y = pos1.y,
		z = math.min(pos1.z, pos2.z),
	}
	local maxp = {
		x = math.max(pos1.x, pos2.x),
		y = pos1.y,
		z = math.max(pos1.z, pos2.z),
	}
	local width = maxp.x - minp.x + 1
	local depth = maxp.z - minp.z + 1
	local nodes = width * depth
	if nodes > 4096 then
		world_edit_marker(player, "Area is too large. Keep flat clears under 4096 blocks.")
		return
	end

	local cleared_nodes = 0
	for x = minp.x, maxp.x do
		for z = minp.z, maxp.z do
			local pos = {x = x, y = minp.y, z = z}
			local node = minetest.get_node(pos)
			if node.name ~= "air" and node.name ~= "ignore" then
				minetest.remove_node(pos)
				cleared_nodes = cleared_nodes + 1
			end
		end
	end

	local removed_entities = remove_entities_in_flat_area(minp, maxp)
	world_edit_selections[name] = nil
	world_edit_marker(player, "Cleared " .. cleared_nodes .. " flat blocks and removed " .. removed_entities .. " entities.")
end

local function use_world_edit_wand(player, pointed_thing)
	local pos = selected_node_pos(pointed_thing)
	if not pos then
		clear_world_edit_area(player)
		return
	end

	local name = player:get_player_name()
	local selection = world_edit_selections[name] or {}
	if not selection.pos1 then
		world_edit_selections[name] = {pos1 = pos}
		world_edit_marker(player, "Corner 1 set at " .. minetest.pos_to_string(pos) .. ". Click another block for corner 2.")
	elseif not selection.pos2 then
		selection.pos2 = pos
		world_edit_selections[name] = selection
		world_edit_marker(player, "Corner 2 set at " .. minetest.pos_to_string(pos) .. ". Click once more with the wand to clear.")
	else
		clear_world_edit_area(player)
	end
end

minetest.register_tool("openclasscraft_creator:world_edit_wand", {
	description = "World Edit Wand\nClick two corners, then click again to clear a flat area and entities",
	inventory_image = "openclasscraft_icon_creator_lab_alpha.png^[colorize:#31d7ff:80",
	groups = {classroom = 1},
	on_use = function(itemstack, user, pointed_thing)
		use_world_edit_wand(user, pointed_thing)
		return itemstack
	end,
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing and pointed_thing.type == "node" then
			use_world_edit_wand(placer, pointed_thing)
			return itemstack
		end
		clear_world_edit_area(placer)
		return itemstack
	end,
	on_secondary_use = function(itemstack, user)
		clear_world_edit_area(user)
		return itemstack
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "openclasscraft_creator:lab" or fields.quit then
		return
	end
	local project = project_for(player)
	if fields.block_name then
		project.name = trim(fields.block_name):sub(1, 40)
	end
	if fields.message then
		project.message = trim(fields.message):sub(1, 160)
	end
	if fields.style then
		project.style = string.lower(fields.style)
	end
	local index = selected_index(fields, project)
	if fields.add_say then
		project.script[#project.script + 1] = "say"
	elseif fields.add_wait then
		project.script[#project.script + 1] = "wait"
	elseif fields.add_gift then
		project.script[#project.script + 1] = "give_apple"
	elseif fields.remove and #project.script > 0 then
		table.remove(project.script, index)
	elseif fields.move_up and index > 1 then
		project.script[index], project.script[index - 1] = project.script[index - 1], project.script[index]
	elseif fields.move_down and index < #project.script then
		project.script[index], project.script[index + 1] = project.script[index + 1], project.script[index]
	elseif fields.save then
		if project.name == "" then
			project.name = "My Learning Block"
		end
		save_project(player:get_player_name(), project)
		minetest.chat_send_player(player:get_player_name(), "[Creator Lab] Project saved for this world.")
	elseif fields.create then
		if project.name == "" then
			project.name = "My Learning Block"
		end
		save_project(player:get_player_name(), project)
		give_project_block(player, project)
	end
	show_creator(player)
	return true
end)
