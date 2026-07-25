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
				vec = {x = self._head_pitch, y = self._head_yaw, z = 0},
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
	local target_pitch = clamp(-math.atan2(direction.y, horizontal_distance),
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
			vec = {x = self._head_pitch, y = self._head_yaw, z = 0},
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

local function can_edit(player, owner)
	if not player or not player:is_player() then
		return false
	end
	local name = player:get_player_name()
	return owner == "" or owner == name or minetest.check_player_privs(name, {server = true})
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
		local name = clicker:get_player_name()
		if clicker:get_player_control().sneak and can_edit(clicker, self._owner) then
			show_npc_form(clicker, self.object)
			return
		end
		send_reference(name, self._title, self._message, self._link)
	end,
})

local function show_chalkboard_form(pos, player)
	local meta = minetest.get_meta(pos)
	minetest.show_formspec(player:get_player_name(),
		"openclasscraft_classroom:chalkboard:" .. minetest.pos_to_string(pos),
		"formspec_version[6]" ..
		"size[12,8]" ..
		"label[0.5,0.5;Chalkboard]" ..
		"field[0.5,1.2;11,0.8;title;Learning goal;" .. esc(meta:get_string("title")) .. "]" ..
		"textarea[0.5,2.3;11,3.3;message;Instructions;" .. esc(meta:get_string("message")) .. "]" ..
		"field[0.5,6.1;11,0.8;link;Reference link;" .. esc(meta:get_string("link")) .. "]" ..
		"button_exit[8.2,7;1.5,0.8;cancel;Cancel]" ..
		"button_exit[9.9,7;1.6,0.8;save;Save]"
	)
end

minetest.register_node("openclasscraft_classroom:chalkboard", {
	description = S("Chalkboard"),
	tiles = {
		"default_wood.png",
		"default_wood.png",
		"default_wood.png",
		"default_wood.png",
		"default_wood.png",
		"default_aspen_wood.png^[colorize:#1C3F2B:160",
	},
	paramtype2 = "facedir",
	groups = {choppy = 2, oddly_breakable_by_hand = 2},
	on_construct = function(pos)
		local meta = minetest.get_meta(pos)
		meta:set_string("title", "Learning Goal")
		meta:set_string("message", "Write lesson instructions here.")
		meta:set_string("link", "")
		meta:set_string("owner", "")
		meta:set_string("infotext", "Chalkboard")
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
		send_reference(clicker:get_player_name(), meta:get_string("title"),
			meta:get_string("message"), meta:get_string("link"))
	end,
})

minetest.register_craftitem("openclasscraft_classroom:guide_npc_spawner", {
	description = S("Guide NPC"),
	inventory_image = "character.png^[resize:64x64",
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
				meta:set_string("infotext", title ~= "" and title or "Chalkboard")
			end
			return true
		end
	end
end)
