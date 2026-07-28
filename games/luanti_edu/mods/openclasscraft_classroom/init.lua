local S = minetest.get_translator("openclasscraft_classroom")

local NPC_GRAVITY = -9.81
local NPC_LOOK_RADIUS = 6
local NPC_HEAD_BONE = "Head"
local NPC_MODEL_YAW_OFFSET = 0
local NPC_BODY_TURN_THRESHOLD = math.rad(60)
local NPC_BODY_TURN_BLEND = 0.12
local NPC_HEAD_SMOOTH_BLEND = 0.25
local NPC_MAX_HEAD_YAW = math.rad(70)
local NPC_MAX_HEAD_PITCH = math.rad(35)

local function clamp(value, minimum, maximum)
	return math.max(minimum, math.min(maximum, value))
end

local function wrap_angle(angle)
	return (angle + math.pi) % (math.pi * 2) - math.pi
end

local function smooth_angle(current, target, blend)
	local difference = wrap_angle(target - current)
	return wrap_angle(current + difference * blend)
end

local function get_nearest_player(pos)
	local closest_player
	local closest_distance = NPC_LOOK_RADIUS * NPC_LOOK_RADIUS

	for _, object in ipairs(minetest.get_objects_inside_radius(pos, NPC_LOOK_RADIUS)) do
		if object:is_player() then
			local player_pos = object:get_pos()
			local distance = vector.distance(pos, player_pos) ^ 2
			if distance < closest_distance then
				closest_player = object
				closest_distance = distance
			end
		end
	end

	return closest_player
end

local function update_npc_head_look(self, dtime)
	if not self.object.set_bone_override then
		return
	end

	local npc_pos = self.object:get_pos()
	local player = npc_pos and get_nearest_player(npc_pos)
	if not player then
		self._head_yaw = smooth_angle(self._head_yaw or 0, 0, NPC_HEAD_SMOOTH_BLEND)
		self._head_pitch = smooth_angle(self._head_pitch or 0, 0, NPC_HEAD_SMOOTH_BLEND)
		self.object:set_bone_override(NPC_HEAD_BONE, {
			rotation = {
				vec = {x = self._head_pitch, y = -self._head_yaw, z = 0},
				interpolation = 0.08,
				absolute = false,
			},
		})
		return
	end

	local player_pos = player:get_pos()
	local player_eye_height = (player:get_properties().eye_height or 1.47)
	player_pos = vector.offset(player_pos, 0, player_eye_height, 0)
	local eye_pos = vector.offset(npc_pos, 0, 1.45, 0)
	local direction = vector.subtract(player_pos, eye_pos)
	local horizontal_distance = math.sqrt(direction.x * direction.x + direction.z * direction.z)
	-- X is pitch (up/down), Y is yaw (left/right), and Z roll stays at zero.
	local target_pitch = clamp(math.atan2(direction.y, horizontal_distance),
		-NPC_MAX_HEAD_PITCH, NPC_MAX_HEAD_PITCH)
	-- minetest.dir_to_yaw is the engine-safe equivalent of atan2(dx, dz).
	local target_yaw = minetest.dir_to_yaw({x = direction.x, y = 0, z = direction.z}) + NPC_MODEL_YAW_OFFSET
	local body_yaw = self.object:get_yaw() or 0
	local body_difference = wrap_angle(target_yaw - body_yaw)

	-- Once the player is farther behind than the neck can turn naturally, let
	-- the body catch up smoothly and keep the head inside its safe range.
	if math.abs(body_difference) > NPC_BODY_TURN_THRESHOLD then
		body_yaw = wrap_angle(body_yaw + body_difference * NPC_BODY_TURN_BLEND)
		self.object:set_yaw(body_yaw)
	end

	local relative_head_yaw = clamp(wrap_angle(target_yaw - body_yaw), -NPC_MAX_HEAD_YAW, NPC_MAX_HEAD_YAW)
	self._head_yaw = smooth_angle(self._head_yaw or 0, relative_head_yaw, NPC_HEAD_SMOOTH_BLEND)
	self._head_pitch = smooth_angle(self._head_pitch or 0, target_pitch, NPC_HEAD_SMOOTH_BLEND)

	self.object:set_bone_override(NPC_HEAD_BONE, {
		rotation = {
			vec = {x = self._head_pitch, y = -self._head_yaw, z = 0},
			interpolation = 0.08,
			absolute = false,
		},
	})
end

local function esc(value)
	return minetest.formspec_escape(value or "")
end

local function trim(value)
	return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function send_reference(name, title, message, link)
	if title ~= "" then
		minetest.chat_send_player(name, "[OpenClassCraft] " .. title)
	end
	if message ~= "" then
		minetest.chat_send_player(name, message)
	end
	if link ~= "" then
		minetest.chat_send_player(name, "Reference: " .. link)
	end
end

local guide_dialogue_links = {}

local function wrap_dialogue(text, line_width)
	local lines = {}
	local line = ""
	for word in (text or ""):gmatch("%S+") do
		if #line > 0 and #line + #word + 1 > line_width then
			lines[#lines + 1] = line
			line = word
		else
			line = line == "" and word or line .. " " .. word
		end
	end
	if line ~= "" then
		lines[#lines + 1] = line
	end
	return table.concat(lines, "\n")
end

local function show_guide_dialogue(player, title, message, link)
	local name = player:get_player_name()
	guide_dialogue_links[name] = link or ""
	local dialogue = wrap_dialogue(message ~= "" and message or "Hello!", 54)
	local reference_button = ""
	if link and link ~= "" then
		reference_button = "button[7.9,5.9;2.0,0.75;reference;Reference]"
	end

	minetest.show_formspec(name, "openclasscraft_classroom:guide_dialogue",
		"formspec_version[6]size[12,7]no_prepend[]bgcolor[#00000000;false]" ..
		"box[0.25,0.3;11.5,5.7;#121826F2]" ..
		"box[0.48,0.53;11.04,5.24;#2A3347]" ..
		"box[0.75,0.8;3.15,0.7;#F2C94C]" ..
		"label[1.0,1.0;CLASS GUIDE]" ..
		"label[0.9,1.78;" .. esc(title ~= "" and title or "Class Guide") .. "]" ..
		"label[0.9,2.4;" .. esc(dialogue) .. "]" ..
		"label[0.9,5.28;Click the guide again any time you need help.]" ..
		reference_button ..
		"button_exit[10.05,5.9;1.2,0.75;close;Close]"
	)
end

local function can_edit(player, owner)
	if not player or not player:is_player() then
		return false
	end
	local name = player:get_player_name()
	return owner == "" or owner == name or minetest.check_player_privs(name, {server = true})
end

local lesson_storage = minetest.get_mod_storage()
local lesson_task_types = {
	chalkboard = "Read chalkboard",
	guide = "Talk to guide",
	marker = "Reach checkpoint",
	water = "Make water",
	teacher = "Teacher check",
}
local lesson_type_order = {"chalkboard", "guide", "marker", "water", "teacher"}

local function get_lesson()
	local data = lesson_storage:get_string("active_lesson")
	if data == "" then
		return {owner = "", title = "", goal = "", tasks = {}, revision = 1}
	end
	local lesson = minetest.deserialize(data)
	if type(lesson) ~= "table" then
		return {owner = "", title = "", goal = "", tasks = {}, revision = 1}
	end
	lesson.owner = lesson.owner or ""
	lesson.title = lesson.title or ""
	lesson.goal = lesson.goal or ""
	lesson.tasks = lesson.tasks or {}
	lesson.revision = lesson.revision or 1
	return lesson
end

local function save_lesson(lesson)
	lesson_storage:set_string("active_lesson", minetest.serialize(lesson))
end

local function get_lesson_progress(player, lesson)
	local meta = player:get_meta()
	if meta:get_int("openclasscraft_lesson_revision") ~= lesson.revision then
		meta:set_int("openclasscraft_lesson_revision", lesson.revision)
		meta:set_int("openclasscraft_lesson_progress", 0)
	end
	return meta:get_int("openclasscraft_lesson_progress")
end

local function set_lesson_progress(player, lesson, progress)
	local meta = player:get_meta()
	meta:set_int("openclasscraft_lesson_revision", lesson.revision)
	meta:set_int("openclasscraft_lesson_progress", progress)
end

local function lesson_try_advance(player, source)
	local lesson = get_lesson()
	if lesson.title == "" or #lesson.tasks == 0 then
		return false
	end
	local progress = get_lesson_progress(player, lesson)
	local task = lesson.tasks[progress + 1]
	if not task or task.kind ~= source then
		return false
	end

	progress = progress + 1
	set_lesson_progress(player, lesson, progress)
	if progress >= #lesson.tasks then
		minetest.chat_send_player(player:get_player_name(),
			"[OpenClassCraft] Lesson complete: " .. lesson.title)
	else
		minetest.chat_send_player(player:get_player_name(),
			"[OpenClassCraft] Task complete. Next: " .. lesson.tasks[progress + 1].text)
	end
	return true
end

local function get_kind_from_label(label)
	for kind, display_name in pairs(lesson_task_types) do
		if label == display_name then
			return kind
		end
	end
	return "teacher"
end

local function show_lesson_builder(player, lesson)
	local task_fields = {}
	for index = 1, 4 do
		local task = lesson.tasks[index] or {kind = "teacher", text = ""}
		local y = 4.25 + (index - 1) * 0.85
		local labels = {}
		local selected_index = 1
		for type_index, kind in ipairs(lesson_type_order) do
			labels[#labels + 1] = lesson_task_types[kind]
			if kind == task.kind then
				selected_index = type_index
			end
		end
		task_fields[#task_fields + 1] =
			"dropdown[0.5," .. y .. ";3.2,0.7;task_type_" .. index .. ";" ..
			table.concat(labels, ",") .. ";" .. selected_index .. ";false]" ..
			"field[3.95," .. (y - 0.05) .. ";9.5,0.7;task_" .. index .. ";;" .. esc(task.text) .. "]"
	end

	local progress_lines = {}
	for _, student in ipairs(minetest.get_connected_players()) do
		local progress = get_lesson_progress(student, lesson)
		progress_lines[#progress_lines + 1] = student:get_player_name() .. ": " ..
			math.min(progress, #lesson.tasks) .. "/" .. #lesson.tasks
	end
	if #progress_lines == 0 then
		progress_lines[1] = "No students connected"
	end

	minetest.show_formspec(player:get_player_name(), "openclasscraft_classroom:lesson_builder",
		"formspec_version[6]size[14,11]" ..
		"label[0.5,0.45;Lesson Builder]" ..
		"field[0.5,1.25;13,0.7;lesson_title;Lesson title;" .. esc(lesson.title) .. "]" ..
		"textarea[0.5,2.0;13,1.35;lesson_goal;Learning goal;" .. esc(lesson.goal) .. "]" ..
		"label[0.5,3.55;Ordered tasks]" ..
		table.concat(task_fields) ..
		"textarea[0.5,7.8;7.2,1.65;progress;Student progress;" ..
			esc(table.concat(progress_lines, "\n")) .. "]" ..
		"button[8.25,8.1;2.2,0.8;reset;Reset progress]" ..
		"button_exit[10.75,8.1;2.2,0.8;save;Save lesson]" ..
		"label[8.25,9.25;Students progress automatically by using the matching classroom tool.]"
	)
end

local function show_lesson_progress(player, lesson)
	local progress = get_lesson_progress(player, lesson)
	local lines = {}
	for index, task in ipairs(lesson.tasks) do
		local status = index <= progress and "Done" or "Next"
		if index > progress + 1 then
			status = "Locked"
		end
		lines[#lines + 1] = status .. " - " .. task.text .. " (" .. lesson_task_types[task.kind] .. ")"
	end
	if #lines == 0 then
		lines[1] = "Your teacher has not added tasks yet."
	end
	local next_task = lesson.tasks[progress + 1]
	local controls = "button_exit[9.6,7.9;2.3,0.8;close;Close]"
	if next_task and next_task.kind == "teacher" then
		controls = "button[7.1,7.9;2.2,0.8;complete;Mark complete]" .. controls
	end
	minetest.show_formspec(player:get_player_name(), "openclasscraft_classroom:lesson_progress",
		"formspec_version[6]size[12.5,9]" ..
		"label[0.5,0.5;" .. esc(lesson.title) .. "]" ..
		"textarea[0.5,1.1;11.5,1.4;goal;Learning goal;" .. esc(lesson.goal) .. "]" ..
		"textarea[0.5,2.85;11.5,4.3;tasks;Lesson tasks;" .. esc(table.concat(lines, "\n")) .. "]" ..
		"label[0.5,7.55;Progress: " .. math.min(progress, #lesson.tasks) .. "/" .. #lesson.tasks .. "]" ..
		controls
	)
end

local function show_lesson_form(player)
	local lesson = get_lesson()
	if can_edit(player, lesson.owner) then
		show_lesson_builder(player, lesson)
	else
		show_lesson_progress(player, lesson)
	end
end

local function show_npc_form(player, obj)
	local entity = obj:get_luaentity()
	if not entity then
		return
	end

	local formname = "openclasscraft_classroom:npc:" .. entity._id
	entity._editor = player:get_player_name()
	minetest.show_formspec(player:get_player_name(), formname,
		"formspec_version[6]" ..
		"size[12,8]" ..
		"label[0.5,0.5;Guide NPC]" ..
		"field[0.5,1.2;5.5,0.8;title;Title;" .. esc(entity._title) .. "]" ..
		"textarea[0.5,2.3;11,3.3;message;Instructions;" .. esc(entity._message) .. "]" ..
		"field[0.5,6.1;11,0.8;link;Reference link;" .. esc(entity._link) .. "]" ..
		"button_exit[8.2,7;1.5,0.8;cancel;Cancel]" ..
		"button_exit[9.9,7;1.6,0.8;save;Save]"
	)
end

minetest.register_entity("openclasscraft_classroom:guide_npc", {
	initial_properties = {
		physical = true,
		collide_with_objects = true,
		collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
		visual = "mesh",
		mesh = "character.b3d",
		textures = {"professor.png"},
		visual_size = {x = 1, y = 1},
		makes_footstep_sound = false,
		static_save = true,
		nametag = "Class Guide",
		nametag_color = "#FFFFFF",
	},
	_id = "",
	_owner = "",
	_title = "Class Guide",
	_message = "Add instructions for students here.",
	_link = "",
	_editor = "",
	_look_timer = 0,
	_head_yaw = 0,
	_head_pitch = 0,

	on_activate = function(self, staticdata)
		self._id = self._id ~= "" and self._id or tostring(math.random(100000, 999999))
		if staticdata and staticdata ~= "" then
			local data = minetest.deserialize(staticdata)
			if data then
				self._id = data.id or self._id
				self._owner = data.owner or ""
				self._title = data.title or self._title
				self._message = data.message or self._message
				self._link = data.link or ""
			end
		end
		self.object:set_nametag_attributes({
			text = self._title ~= "" and self._title or "Class Guide",
			color = "#FFFFFF",
		})
		self.object:set_acceleration(vector.new(0, NPC_GRAVITY, 0))
	end,

	on_step = function(self, dtime)
		self._look_timer = self._look_timer + dtime
		if self._look_timer < 0.05 then
			return
		end
		local look_dtime = self._look_timer
		self._look_timer = 0
		update_npc_head_look(self, look_dtime)
	end,

	get_staticdata = function(self)
		return minetest.serialize({
			id = self._id,
			owner = self._owner,
			title = self._title,
			message = self._message,
			link = self._link,
		})
	end,

	on_rightclick = function(self, clicker)
		if clicker:get_player_control().sneak and can_edit(clicker, self._owner) then
			show_npc_form(clicker, self.object)
			return
		end
		show_guide_dialogue(clicker, self._title, self._message, self._link)
		lesson_try_advance(clicker, "guide")
	end,
})

local function show_chalkboard_form(pos, player)
	local meta = minetest.get_meta(pos)
	local board_name = meta:get_string("board_name")
	if board_name == "" then
		board_name = "Classroom Board"
	end
	minetest.show_formspec(player:get_player_name(),
		"openclasscraft_classroom:chalkboard:" .. minetest.pos_to_string(pos),
		"formspec_version[6]" ..
		"size[13,10]" ..
		"label[0.5,0.5;" .. esc(board_name) .. " Editor]" ..
		"field[0.5,1.25;12,0.8;title;Heading (optional);" .. esc(meta:get_string("title")) .. "]" ..
		"textarea[0.5,2.2;12,5.5;message;Board text;" .. esc(meta:get_string("message")) .. "]" ..
		"field[0.5,8.0;12,0.8;link;Reference link;" .. esc(meta:get_string("link")) .. "]" ..
		"button_exit[9.2,9;1.5,0.8;cancel;Cancel]" ..
		"button_exit[10.9,9;1.6,0.8;save;Save]"
	)
end

local board_reading_links = {}

local function show_board_reading_form(pos, player)
	local meta = minetest.get_meta(pos)
	local name = player:get_player_name()
	board_reading_links[name] = meta:get_string("link")
	local reference_button = ""
	if board_reading_links[name] ~= "" then
		reference_button = "button[8.8,7.9;2.0,0.8;reference;Reference]"
	end
	minetest.show_formspec(name, "openclasscraft_classroom:board_reading",
		"formspec_version[6]size[12,9]" ..
		"box[0.3,0.3;11.4,7.2;#11161DE8]" ..
		"label[0.7,0.75;" .. esc(meta:get_string("title")) .. "]" ..
		"textarea[0.7,1.35;10.6,5.7;instructions;Instructions;" .. esc(meta:get_string("message")) .. "]" ..
		reference_button ..
		"button_exit[10.9,7.9;0.8,0.8;close;Close]"
	)
end

local legacy_board_label_entity = "openclasscraft_classroom:board_label"
local board_surface_entity = "openclasscraft_classroom:board_surface"

local BOARD_FONT = {
	["A"] = {"010", "101", "111", "101", "101"}, ["B"] = {"110", "101", "110", "101", "110"},
	["C"] = {"011", "100", "100", "100", "011"}, ["D"] = {"110", "101", "101", "101", "110"},
	["E"] = {"111", "100", "110", "100", "111"}, ["F"] = {"111", "100", "110", "100", "100"},
	["G"] = {"011", "100", "101", "101", "011"}, ["H"] = {"101", "101", "111", "101", "101"},
	["I"] = {"111", "010", "010", "010", "111"}, ["J"] = {"001", "001", "001", "101", "010"},
	["K"] = {"101", "101", "110", "101", "101"}, ["L"] = {"100", "100", "100", "100", "111"},
	["M"] = {"101", "111", "111", "101", "101"}, ["N"] = {"101", "111", "111", "111", "101"},
	["O"] = {"010", "101", "101", "101", "010"}, ["P"] = {"110", "101", "110", "100", "100"},
	["Q"] = {"010", "101", "101", "011", "001"}, ["R"] = {"110", "101", "110", "101", "101"},
	["S"] = {"011", "100", "010", "001", "110"}, ["T"] = {"111", "010", "010", "010", "010"},
	["U"] = {"101", "101", "101", "101", "111"}, ["V"] = {"101", "101", "101", "101", "010"},
	["W"] = {"101", "101", "111", "111", "101"}, ["X"] = {"101", "101", "010", "101", "101"},
	["Y"] = {"101", "101", "010", "010", "010"}, ["Z"] = {"111", "001", "010", "100", "111"},
	["0"] = {"111", "101", "101", "101", "111"}, ["1"] = {"010", "110", "010", "010", "111"},
	["2"] = {"110", "001", "010", "100", "111"}, ["3"] = {"110", "001", "010", "001", "110"},
	["4"] = {"101", "101", "111", "001", "001"}, ["5"] = {"111", "100", "110", "001", "110"},
	["6"] = {"011", "100", "110", "101", "010"}, ["7"] = {"111", "001", "010", "010", "010"},
	["8"] = {"010", "101", "010", "101", "010"}, ["9"] = {"010", "101", "011", "001", "110"},
	["."] = {"000", "000", "000", "000", "010"}, [","] = {"000", "000", "000", "010", "100"},
	["!"] = {"010", "010", "010", "000", "010"}, ["?"] = {"110", "001", "010", "000", "010"},
	[":"] = {"000", "010", "000", "010", "000"}, ["-"] = {"000", "000", "111", "000", "000"},
	["+"] = {"000", "010", "111", "010", "000"}, ["/"] = {"001", "001", "010", "100", "100"},
	["("] = {"001", "010", "010", "010", "001"}, [")"] = {"100", "010", "010", "010", "100"},
	[" "] = {"000", "000", "000", "000", "000"}, ["_"] = {"000", "000", "000", "000", "111"},
}

local function board_lines(meta)
	local lines = {}
	local title = trim(meta:get_string("title"))
	local message = trim(meta:get_string("message")):gsub("%s+", " ")
	if title ~= "" then
		table.insert(lines, {text = title:sub(1, 24), scale = 3})
	end
	if message ~= "" then
		for line in wrap_dialogue(message, 30):gmatch("[^\n]+") do
			table.insert(lines, {text = line:sub(1, 30), scale = 2})
			if #lines >= 5 then
				break
			end
		end
	end
	return lines
end

local function board_texture(meta)
	local lines = board_lines(meta)
	if #lines == 0 then
		return nil
	end

	local width, height = 384, 224
	local pixels = {}
	local text_color = meta:get_string("board_name") == "Large Whiteboard" and "\027\036\048\255" or "\255\255\255\255"
	local marked = {}
	local function mark(x, y)
		if x >= 0 and x < width and y >= 0 and y < height then
			marked[y * width + x] = true
		end
	end
	local function draw_text(text, x, y, scale)
		for index = 1, #text do
			local glyph = BOARD_FONT[text:sub(index, index):upper()] or BOARD_FONT["?"]
			for row = 1, 5 do
				for column = 1, 3 do
					if glyph[row]:sub(column, column) == "1" then
						for offset_y = 0, scale - 1 do
							for offset_x = 0, scale - 1 do
								mark(x + (index - 1) * scale * 4 + (column - 1) * scale + offset_x,
									y + (row - 1) * scale + offset_y)
							end
						end
					end
				end
			end
		end
	end

	local y = 18
	for _, line in ipairs(lines) do
		draw_text(line.text, 18, y, line.scale)
		y = y + line.scale * 7 + 11
	end

	local transparent = "\000\000\000\000"
	for row = 0, height - 1 do
		local output = {}
		for column = 0, width - 1 do
			output[#output + 1] = marked[row * width + column] and text_color or transparent
		end
		pixels[#pixels + 1] = table.concat(output)
	end
	return "[png:" .. minetest.encode_base64(minetest.encode_png(width, height, table.concat(pixels)))
end

local function same_board_position(first, second)
	return first and second and first.x == second.x and first.y == second.y and first.z == second.z
end

local function board_surface_position(pos)
	local direction = minetest.facedir_to_dir(minetest.get_node(pos).param2)
	return {
		x = pos.x - direction.x * 0.515,
		y = pos.y + 0.12,
		z = pos.z - direction.z * 0.515,
	}
end

local function remove_board_surface(pos)
	for _, object in ipairs(minetest.get_objects_inside_radius(pos, 3)) do
		local entity = object:get_luaentity()
		if entity and (entity.name == board_surface_entity or entity.name == legacy_board_label_entity)
			and same_board_position(entity._board_pos, pos) then
			object:remove()
		end
	end
end

local function update_board_surface(pos)
	local meta = minetest.get_meta(pos)
	local texture = board_texture(meta)
	if not texture then
		remove_board_surface(pos)
		return
	end
	local surface_pos = board_surface_position(pos)
	local direction = minetest.facedir_to_dir(minetest.get_node(pos).param2)

	for _, object in ipairs(minetest.get_objects_inside_radius(pos, 3)) do
		local entity = object:get_luaentity()
		if entity and entity.name == board_surface_entity and same_board_position(entity._board_pos, pos) then
			object:set_pos(surface_pos)
			object:set_yaw(minetest.dir_to_yaw(direction))
			object:set_properties({textures = {texture, texture, texture, texture, texture, texture}})
			return
		end
	end

	remove_board_surface(pos)
	local object = minetest.add_entity(surface_pos, board_surface_entity)
	if object then
		local entity = object:get_luaentity()
		entity._board_pos = vector.new(pos)
		object:set_yaw(minetest.dir_to_yaw(direction))
		object:set_properties({textures = {texture, texture, texture, texture, texture, texture}})
	end
end

minetest.register_entity(board_surface_entity, {
	initial_properties = {
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "cube",
		textures = {"blank.png", "blank.png", "blank.png", "blank.png", "blank.png", "blank.png"},
		visual_size = {x = 2.72, y = 1.55, z = 0.01},
		use_texture_alpha = true,
		static_save = false,
	},
	_board_pos = nil,
})

local function register_classroom_board(name, description, surface_texture)
	minetest.register_node(name, {
		description = S(description),
		drawtype = "nodebox",
		tiles = {
			"default_acacia_wood.png",
			"default_acacia_wood.png",
			"default_acacia_wood.png",
			"default_acacia_wood.png",
			"default_acacia_wood.png",
			surface_texture,
		},
		inventory_image = surface_texture,
		paramtype2 = "facedir",
		groups = {choppy = 2, oddly_breakable_by_hand = 2},
		node_box = {
			type = "fixed",
			fixed = {-1.45, -0.5, 0.38, 1.45, 1.25, 0.5},
		},
		selection_box = {
			type = "fixed",
			fixed = {-1.45, -0.5, 0.38, 1.45, 1.25, 0.5},
		},
		on_construct = function(pos)
			local meta = minetest.get_meta(pos)
			meta:set_string("title", "")
			meta:set_string("message", "")
			meta:set_string("link", "")
			meta:set_string("owner", "")
			meta:set_string("board_name", description)
			meta:set_string("infotext", description)
			update_board_surface(pos)
		end,
		after_place_node = function(pos, placer)
			if placer and placer:is_player() then
				local meta = minetest.get_meta(pos)
				meta:set_string("owner", placer:get_player_name())
				show_chalkboard_form(pos, placer)
			end
		end,
		on_rightclick = function(pos, node, clicker)
			local meta = minetest.get_meta(pos)
			if clicker:get_player_control().sneak and can_edit(clicker, meta:get_string("owner")) then
				show_chalkboard_form(pos, clicker)
				return
			end
			show_board_reading_form(pos, clicker)
			lesson_try_advance(clicker, "chalkboard")
		end,
		on_punch = function(pos, node, puncher)
			if puncher and puncher:is_player() then
				local meta = minetest.get_meta(pos)
				if can_edit(puncher, meta:get_string("owner")) then
					show_chalkboard_form(pos, puncher)
				end
			end
		end,
		on_destruct = function(pos)
			remove_board_surface(pos)
		end,
	})
end

register_classroom_board("openclasscraft_classroom:chalkboard", "Large Blackboard",
	"default_obsidian.png^[colorize:#111820:210")
register_classroom_board("openclasscraft_classroom:whiteboard", "Large Whiteboard",
	"default_paper.png^[colorize:#F4F2EA:100")

minetest.register_lbm({
	name = "openclasscraft_classroom:restore_board_labels",
	nodenames = {"openclasscraft_classroom:chalkboard", "openclasscraft_classroom:whiteboard"},
	run_at_every_load = true,
	action = function(pos)
		local meta = minetest.get_meta(pos)
		if meta:get_string("title") == "Learning Goal"
			and meta:get_string("message") == "Write lesson instructions here." then
			meta:set_string("title", "")
			meta:set_string("message", "")
		end
		update_board_surface(pos)
	end,
})

local function register_atom(name, description, color)
	minetest.register_craftitem("openclasscraft_classroom:" .. name, {
		description = S(description),
		inventory_image = "default_mese_crystal_fragment.png^[colorize:" .. color .. ":145",
	})
end

register_atom("hydrogen_atom", "Hydrogen Atom", "#7BE7FF")
register_atom("oxygen_atom", "Oxygen Atom", "#FF6B6B")
register_atom("carbon_atom", "Carbon Atom", "#4A4A4A")
register_atom("nitrogen_atom", "Nitrogen Atom", "#7C8CFF")
register_atom("sodium_atom", "Sodium Atom", "#F7D56A")
register_atom("chlorine_atom", "Chlorine Atom", "#75E68A")

minetest.register_craftitem("openclasscraft_classroom:water_molecule", {
	description = S("Water Molecule (H2O)"),
	inventory_image = "default_water.png^[colorize:#5CDFFF:80",
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then
			return itemstack
		end
		local pos = pointed_thing.above
		if minetest.is_protected(pos, placer:get_player_name()) then
			minetest.record_protection_violation(pos, placer:get_player_name())
			return itemstack
		end
		local node = minetest.get_node(pos)
		local definition = minetest.registered_nodes[node.name]
		if not definition or not definition.buildable_to then
			return itemstack
		end
		minetest.set_node(pos, {name = "default:water_source"})
		if not minetest.is_creative_enabled(placer:get_player_name()) then
			itemstack:take_item()
		end
		return itemstack
	end,
})

local function register_molecule(name, description, color)
	minetest.register_craftitem("openclasscraft_classroom:" .. name, {
		description = S(description),
		inventory_image = "default_mese_crystal.png^[colorize:" .. color .. ":130",
	})
end

register_molecule("oxygen_molecule", "Oxygen Molecule (O2)", "#A5D8FF")
register_molecule("hydrogen_molecule", "Hydrogen Molecule (H2)", "#EAFBFF")
register_molecule("carbon_dioxide", "Carbon Dioxide (CO2)", "#9DA1A8")
register_molecule("sodium_chloride", "Salt (NaCl)", "#FFF7E8")
register_molecule("ammonia", "Ammonia (NH3)", "#BFE6FF")
register_molecule("methane", "Methane (CH4)", "#B9F58C")

local CHEMISTRY_REACTIONS = {
	water = {
		label = "Water (H2O)",
		formula = "2 Hydrogen + 1 Oxygen -> Water",
		product = "openclasscraft_classroom:water_molecule",
		requirements = {hydrogen_atom = 2, oxygen_atom = 1},
	},
	oxygen = {
		label = "Oxygen (O2)",
		formula = "2 Oxygen -> Oxygen gas",
		product = "openclasscraft_classroom:oxygen_molecule",
		requirements = {oxygen_atom = 2},
	},
	hydrogen = {
		label = "Hydrogen (H2)",
		formula = "2 Hydrogen -> Hydrogen gas",
		product = "openclasscraft_classroom:hydrogen_molecule",
		requirements = {hydrogen_atom = 2},
	},
	carbon_dioxide = {
		label = "Carbon dioxide (CO2)",
		formula = "1 Carbon + 2 Oxygen -> Carbon dioxide",
		product = "openclasscraft_classroom:carbon_dioxide",
		requirements = {carbon_atom = 1, oxygen_atom = 2},
	},
	salt = {
		label = "Salt (NaCl)",
		formula = "1 Sodium + 1 Chlorine -> Salt",
		product = "openclasscraft_classroom:sodium_chloride",
		requirements = {sodium_atom = 1, chlorine_atom = 1},
	},
	ammonia = {
		label = "Ammonia (NH3)",
		formula = "1 Nitrogen + 3 Hydrogen -> Ammonia",
		product = "openclasscraft_classroom:ammonia",
		requirements = {nitrogen_atom = 1, hydrogen_atom = 3},
	},
	methane = {
		label = "Methane (CH4)",
		formula = "1 Carbon + 4 Hydrogen -> Methane",
		product = "openclasscraft_classroom:methane",
		requirements = {carbon_atom = 1, hydrogen_atom = 4},
	},
}

local CHEMISTRY_REACTION_ORDER = {
	"water", "oxygen", "hydrogen", "carbon_dioxide", "salt", "ammonia", "methane",
}

local function inventory_count(inventory, item_name)
	local count = 0
	for _, stack in ipairs(inventory:get_list("main") or {}) do
		if stack:get_name() == item_name then
			count = count + stack:get_count()
		end
	end
	return count
end

local function make_chemistry_item(player, reaction_key)
	local reaction = CHEMISTRY_REACTIONS[reaction_key]
	if not reaction then
		return false, "Choose a reaction first."
	end
	local inventory = player:get_inventory()
	for atom, count in pairs(reaction.requirements) do
		if not inventory:contains_item("main", ItemStack("openclasscraft_classroom:" .. atom .. " " .. count)) then
			return false, "Missing atoms for " .. reaction.label .. "."
		end
	end
	local product = ItemStack(reaction.product)
	local look = player:get_look_dir()
	local horizontal_length = math.sqrt(look.x * look.x + look.z * look.z)
	if horizontal_length < 0.001 then
		horizontal_length = 1
		look = {x = 0, y = 0, z = 1}
	end
	local spawn_pos = vector.add(player:get_pos(), {
		x = look.x / horizontal_length * 3,
		y = 0.8,
		z = look.z / horizontal_length * 3,
	})
	local result = minetest.add_item(spawn_pos, product)
	if not result then
		return false, "The reaction could not create an item. Try again."
	end
	for atom, count in pairs(reaction.requirements) do
		inventory:remove_item("main", ItemStack("openclasscraft_classroom:" .. atom .. " " .. count))
	end
	result:set_velocity({x = look.x / horizontal_length * 1.5, y = 1.2, z = look.z / horizontal_length * 1.5})
	return true, reaction.label .. " appeared three blocks in front of you."
end

local function show_chemistry_lab_form(player, status)
	local inventory = player:get_inventory()
	local hydrogen_count = inventory_count(inventory, "openclasscraft_classroom:hydrogen_atom")
	local oxygen_count = inventory_count(inventory, "openclasscraft_classroom:oxygen_atom")
	local carbon_count = inventory_count(inventory, "openclasscraft_classroom:carbon_atom")
	local nitrogen_count = inventory_count(inventory, "openclasscraft_classroom:nitrogen_atom")
	local sodium_count = inventory_count(inventory, "openclasscraft_classroom:sodium_atom")
	local chlorine_count = inventory_count(inventory, "openclasscraft_classroom:chlorine_atom")
	local selected_key = player:get_meta():get_string("openclasscraft_selected_reaction")
	if not CHEMISTRY_REACTIONS[selected_key] then
		selected_key = "water"
	end
	local reaction_labels = {}
	local selected_index = 1
	for index, key in ipairs(CHEMISTRY_REACTION_ORDER) do
		table.insert(reaction_labels, CHEMISTRY_REACTIONS[key].label)
		if key == selected_key then
			selected_index = index
		end
	end
	local selected_reaction = CHEMISTRY_REACTIONS[selected_key]
	minetest.show_formspec(player:get_player_name(), "openclasscraft_classroom:chemistry_lab",
		"formspec_version[6]size[6.2,7.2]" ..
		"label[0.5,0.5;Chemistry Lab]" ..
		"box[0.45,1.05;5.35,5.2;#23435FE8]" ..
		"label[0.8,1.4;Build a real substance]" ..
		"dropdown[0.8,2.0;4.5,0.8;reaction;" .. esc(table.concat(reaction_labels, ",")) .. ";" .. selected_index .. ";false]" ..
		"label[0.8,2.85;" .. esc(selected_reaction.formula) .. "]" ..
		"label[0.8,3.45;H: " .. hydrogen_count .. "  O: " .. oxygen_count .. "  C: " .. carbon_count .. "]" ..
		"label[0.8,3.85;N: " .. nitrogen_count .. "  Na: " .. sodium_count .. "  Cl: " .. chlorine_count .. "]" ..
		"button[1.65,4.55;2.9,0.9;make_water;Create item]" ..
		"label[0.65,6.45;" .. esc(status or "Choose a reaction and create a real substance.") .. "]" ..
		"button_exit[4.1,6.45;1.4,0.6;close;Close]"
	)
end

minetest.register_node("openclasscraft_classroom:chemistry_lab", {
	description = S("Chemistry Lab"),
	tiles = {
		"default_steel_block.png^[colorize:#40B9D5:85",
		"default_steel_block.png^[colorize:#40B9D5:85",
		"default_steel_block.png^[colorize:#275C85:110",
		"default_steel_block.png^[colorize:#275C85:110",
		"default_steel_block.png^[colorize:#275C85:110",
		"default_steel_block.png^[colorize:#6AE9FF:95",
	},
	groups = {cracky = 2, oddly_breakable_by_hand = 2},
	on_construct = function(pos)
		minetest.get_meta(pos):set_string("infotext", "Chemistry Lab")
	end,
	on_rightclick = function(pos, node, clicker)
		show_chemistry_lab_form(clicker)
	end,
})

minetest.register_node("openclasscraft_classroom:lesson_marker", {
	description = S("Lesson Checkpoint Flag"),
	drawtype = "mesh",
	mesh = "openclasscraft_classroom_checkpoint_flag.obj",
	-- Mesh material slots are ordered by material name: cloth, then stand.
	tiles = {"openclasscraft_classroom_flag_red.png", "default_steel_block.png"},
	inventory_image = "openclasscraft_classroom_flag_red.png",
	paramtype2 = "facedir",
	groups = {cracky = 2, oddly_breakable_by_hand = 2},
	selection_box = {
		type = "fixed",
		fixed = {-0.28, -0.5, -0.28, 0.52, 1.35, 0.28},
	},
	on_rightclick = function(pos, node, clicker)
		if lesson_try_advance(clicker, "marker") then
			minetest.chat_send_player(clicker:get_player_name(),
				"[OpenClassCraft] Checkpoint reached.")
		end
	end,
})

minetest.register_craftitem("openclasscraft_classroom:lesson_planner", {
	description = S("Lesson Planner"),
	inventory_image = "default_book.png^[colorize:#39B6E8:85",
	on_use = function(itemstack, user)
		if user and user:is_player() then
			show_lesson_form(user)
		end
		return itemstack
	end,
})

minetest.register_craftitem("openclasscraft_classroom:guide_npc_spawner", {
	description = S("Guide NPC"),
	inventory_image = "openclasscraft_classroom_guide_npc.png",
	on_place = function(itemstack, placer, pointed_thing)
		if pointed_thing.type ~= "node" then
			return itemstack
		end
		local pos = vector.offset(pointed_thing.above, 0, 0, 0)
		local obj = minetest.add_entity(pos, "openclasscraft_classroom:guide_npc")
		if obj then
			local entity = obj:get_luaentity()
			entity._owner = placer:get_player_name()
			entity._title = "Class Guide"
			entity._message = "Add instructions for students here."
			entity._link = ""
			show_npc_form(placer, obj)
			if not minetest.is_creative_enabled(placer:get_player_name()) then
				itemstack:take_item()
			end
		end
		return itemstack
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname == "openclasscraft_classroom:chemistry_lab" then
		if fields.make_water then
			local reaction_key = player:get_meta():get_string("openclasscraft_selected_reaction")
			for _, key in ipairs(CHEMISTRY_REACTION_ORDER) do
				if fields.reaction == CHEMISTRY_REACTIONS[key].label then
					reaction_key = key
					break
				end
			end
			if not CHEMISTRY_REACTIONS[reaction_key] then
				reaction_key = "water"
			end
			player:get_meta():set_string("openclasscraft_selected_reaction", reaction_key)
			local made_item, status = make_chemistry_item(player, reaction_key)
			if made_item and reaction_key == "water" then
				local completed = lesson_try_advance(player, "water")
				if not completed then
					status = status .. " Add a Make water task to the lesson to record progress."
				end
			end
			show_chemistry_lab_form(player, status)
			return true
		end

		return true
	end

	if formname == "openclasscraft_classroom:guide_dialogue" then
		if fields.reference then
			local link = guide_dialogue_links[player:get_player_name()]
			if link and link ~= "" then
				minetest.chat_send_player(player:get_player_name(), "Reference: " .. link)
			end
		end
		return true
	end

	if formname == "openclasscraft_classroom:board_reading" then
		if fields.reference then
			local link = board_reading_links[player:get_player_name()]
			if link and link ~= "" then
				minetest.chat_send_player(player:get_player_name(), "Reference: " .. link)
			end
		end
		return true
	end

	if formname == "openclasscraft_classroom:lesson_builder" then
		local lesson = get_lesson()
		if not can_edit(player, lesson.owner) then
			return true
		end
		if fields.reset then
			lesson.revision = lesson.revision + 1
			save_lesson(lesson)
			show_lesson_builder(player, lesson)
			return true
		end
		if fields.save then
			lesson.owner = lesson.owner ~= "" and lesson.owner or player:get_player_name()
			lesson.title = trim(fields.lesson_title)
			lesson.goal = trim(fields.lesson_goal)
			lesson.tasks = {}
			for index = 1, 4 do
				local text = trim(fields["task_" .. index])
				if text ~= "" then
					lesson.tasks[#lesson.tasks + 1] = {
						kind = get_kind_from_label(fields["task_type_" .. index]),
						text = text,
					}
				end
			end
			lesson.revision = lesson.revision + 1
			save_lesson(lesson)
			minetest.chat_send_player(player:get_player_name(),
				"[OpenClassCraft] Lesson saved. Students can open the Lesson Planner to begin.")
			return true
		end
		return true
	end

	if formname == "openclasscraft_classroom:lesson_progress" then
		if fields.complete then
			lesson_try_advance(player, "teacher")
			show_lesson_progress(player, get_lesson())
		end
		return true
	end

	if not fields.save then
		return
	end

	local npc_id = formname:match("^openclasscraft_classroom:npc:(%d+)$")
	if npc_id then
		for _, obj in ipairs(minetest.get_objects_inside_radius(player:get_pos(), 64)) do
			local entity = obj:get_luaentity()
			if entity and entity.name == "openclasscraft_classroom:guide_npc" and entity._id == npc_id then
				if can_edit(player, entity._owner) then
					entity._title = trim(fields.title)
					entity._message = trim(fields.message)
					entity._link = trim(fields.link)
					obj:set_nametag_attributes({text = entity._title ~= "" and entity._title or "Class Guide"})
				end
				return true
			end
		end
	end

	local pos_string = formname:match("^openclasscraft_classroom:chalkboard:(.+)$")
	if pos_string then
		local pos = minetest.string_to_pos(pos_string)
		if pos then
			local meta = minetest.get_meta(pos)
			if can_edit(player, meta:get_string("owner")) then
				local title = trim(fields.title)
				local message = trim(fields.message)
				local link = trim(fields.link)
				meta:set_string("title", title)
				meta:set_string("message", message)
				meta:set_string("link", link)
				meta:set_string("infotext", title ~= "" and title or meta:get_string("board_name"))
				update_board_surface(pos)
			end
			return true
		end
	end
end)
