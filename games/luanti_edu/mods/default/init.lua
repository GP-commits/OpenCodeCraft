-- Minetest Game mod: default
-- See README.txt for licensing and other information.

-- The API documentation in here was moved into game_api.txt

-- Load support for MT game translation.
local S = minetest.get_translator("default")

-- Definitions made by this mod that other mods can use too
default = {}

default.LIGHT_MAX = 14
default.get_translator = S

-- Check for engine features required by MTG
-- This provides clear error behavior when MTG is newer than the installed engine
-- and avoids obscure, hard to debug runtime errors.
-- This section should be updated before release and older checks can be dropped
-- when newer ones are introduced.
if core.get_mapgen_edges == nil then
	error("\nThis version of Minetest Game is incompatible with your engine version "..
		"(which is too old). You should download a version of Minetest Game that "..
		"matches the installed engine version.\n")
end

-- GUI related stuff
local function default_setting_enabled(name)
	return minetest.settings:get_bool(name, false)
end

local function default_build_formspec_prepend(player)
	local high_contrast = default_setting_enabled("openclasscraft_high_contrast")
	local colorblind = default_setting_enabled("openclasscraft_colorblind_support")
	local large_ui = default_setting_enabled("openclasscraft_large_ui")

	local bgcolor = high_contrast and "#000000F4" or "#08080870"
	local normal = high_contrast and "#111111F8" or "#00000048"
	local hover = high_contrast and "#2D3748" or "#5A5A5A"
	local border = high_contrast and "#FFFFFF" or "#141318"
	local selected = colorblind and "#0072B2" or "#30434C"
	local text = "#FFFFFF"

	local formspec = ("bgcolor[%s;true]listcolors[%s;%s;%s;%s;%s]"):format(
		bgcolor, normal, hover, border, selected, text)
	local name = player:get_player_name()
	local info = minetest.get_player_information(name)
	if info.formspec_version > 1 then
		formspec = formspec .. "background9[5,5;1,1;gui_formbg.png;true;10]"
	else
		formspec = formspec .. "background[5,5;1,1;gui_formbg.png;true]"
	end

	if large_ui then
		formspec = formspec ..
			"style_type[button;font_size=+4]" ..
			"style_type[label;font_size=+3]" ..
			"style_type[field;font_size=+3]"
	end

	return formspec
end

local original_chat_send_player = minetest.chat_send_player

function minetest.chat_send_player(name, message)
	original_chat_send_player(name, message)

	if not default_setting_enabled("openclasscraft_read_aloud") then
		return
	end
	if type(message) ~= "string" or message:find("%[Read aloud%]") then
		return
	end
	if message:find("%[Luanti Edu%]") or message:find("%[OpenClassCraft%]") then
		local clean = message
			:gsub("%[Luanti Edu%]%s*", "")
			:gsub("%[OpenClassCraft%]%s*", "")
			:gsub("[✓✗■]", "")
			:gsub("%s+", " ")
		original_chat_send_player(name, "[Read aloud] " .. clean)
	end
end

minetest.register_on_joinplayer(function(player)
	-- Set formspec prepend
	player:set_formspec_prepend(default_build_formspec_prepend(player))

	-- Set hotbar textures
	player:hud_set_hotbar_image("gui_hotbar.png")
	player:hud_set_hotbar_selected_image("gui_hotbar_selected.png")
	if default_setting_enabled("openclasscraft_large_ui") then
		player:hud_set_hotbar_itemcount(6)
	elseif default_setting_enabled("openclasscraft_simplified_controls") then
		player:hud_set_hotbar_itemcount(5)
	end
	if default_setting_enabled("openclasscraft_simplified_controls") then
		player:hud_set_flags({
			minimap = false,
			minimap_radar = false,
			basic_debug = false,
			wielditem = false,
			crosshair = true,
			hotbar = true,
		})
	end
	if default_setting_enabled("openclasscraft_read_aloud") then
		minetest.chat_send_player(player:get_player_name(),
			"[Read aloud] Accessibility helpers are enabled.")
	end
end)

function default.get_hotbar_bg(x,y)
	local out = ""
	for i=0,7,1 do
		out = out .."image["..x+i..","..y..";1,1;gui_hb_bg.png]"
	end
	return out
end

default.gui_survival_form = "size[8,8.5]"..
			"list[current_player;main;0,4.25;8,1;]"..
			"list[current_player;main;0,5.5;8,3;8]"..
			"list[current_player;craft;1.75,0.5;3,3;]"..
			"list[current_player;craftpreview;5.75,1.5;1,1;]"..
			"image[4.75,1.5;1,1;gui_furnace_arrow_bg.png^[transformR270]"..
			"listring[current_player;main]"..
			"listring[current_player;craft]"..
			default.get_hotbar_bg(0,4.25)

-- Load files
local default_path = minetest.get_modpath("default")

dofile(default_path.."/functions.lua")
dofile(default_path.."/trees.lua")
dofile(default_path.."/nodes.lua")
dofile(default_path.."/chests.lua")
dofile(default_path.."/furnace.lua")
dofile(default_path.."/torch.lua")
dofile(default_path.."/tools.lua")
dofile(default_path.."/item_entity.lua")
dofile(default_path.."/craftitems.lua")
dofile(default_path.."/crafting.lua")
dofile(default_path.."/mapgen.lua")
dofile(default_path.."/chat.lua")
dofile(default_path.."/aliases.lua")
dofile(default_path.."/legacy.lua")

-- Smoke test that is run via ./util/test/run.sh
if minetest.settings:get_bool("minetest_game_smoke_test") then
	minetest.after(0, function()
		minetest.emerge_area(vector.new(0, 0, 0), vector.new(32, 32, 32))
		local pos = vector.new(9, 9, 9)
		local function check()
			if minetest.get_node(pos).name ~= "ignore" then
				minetest.request_shutdown()
				return
			end
			minetest.after(0, check)
		end
		check()
	end)
end
