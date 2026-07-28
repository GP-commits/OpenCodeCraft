-- Luanti
-- Copyright (C) 2013 sapier
-- SPDX-License-Identifier: LGPL-2.1-or-later


local function prepare_credits(dest, source)
	local string = table.concat(source, "\n") .. "\n"

	string = core.hypertext_escape(string)
	string = string:gsub("%[.-%]", "<gray>%1</gray>")

	table.insert(dest, string)
end

local function get_credits()
	local f = assert(io.open(core.get_mainmenu_path() .. "/credits.json"))
	local json = core.parse_json(f:read("*all"))
	f:close()
	return json
end

local function get_renderer_info()
	local ret = {}

	-- OpenGL version, stripped to just the important part
	local s1 = core.get_active_renderer()
	if s1:sub(1, 7) == "OpenGL " then
		s1 = s1:sub(8)
	end
	local m = s1:match("^[%d.]+")
	if not m then
		m = s1:match("^ES [%d.]+")
	end
	ret[#ret+1] = m or s1
	-- video driver
	ret[#ret+1] = core.get_active_driver():lower()
	-- irrlicht device
	ret[#ret+1] = core.get_active_irrlicht_device():upper()

	return table.concat(ret, " / ")
end

return {
	name = "about",
	caption = fgettext("About"),

	cbf_formspec = function(tabview, name, tabdata)
		local engine_logofile = defaulttexturedir .. "luanti_attribution_logo.png"
		local version = core.get_version()

		-- Get game details for OpenClassCraft
		local game = pkgmgr.games[1]
		local game_logo = game and (game.path .. "/menu/icon.png") or engine_logofile
		local game_title = game and game.title or "OpenClassCraft"

		local hypertext = {
			"<tag name=heading color=#ff0>",
			"<tag name=gray color=#aaa>",
		}

		local credits = get_credits()

		table.insert_all(hypertext, {
			"<heading>", core.hypertext_escape("OpenClassCraft Developer"), "</heading>\n",
			core.hypertext_escape("Sivadarsh P Dinesh <sivadarshpdinesh@gmail.com>"), "\n",
			"\n",
			"<heading>", fgettext_ne("Core Developers"), "</heading>\n",
		})
		prepare_credits(hypertext, credits.core_developers)
		table.insert_all(hypertext, {
			"\n",
			"<heading>", fgettext_ne("Core Team"), "</heading>\n",
		})
		prepare_credits(hypertext, credits.core_team)
		table.insert_all(hypertext, {
			"\n",
			"<heading>", fgettext_ne("Active Contributors"), "</heading>\n",
		})
		prepare_credits(hypertext, credits.contributors)
		table.insert_all(hypertext, {
			"\n",
			"<heading>", fgettext_ne("Previous Core Developers"), "</heading>\n",
		})
		prepare_credits(hypertext, credits.previous_core_developers)
		table.insert_all(hypertext, {
			"\n",
			"<heading>", fgettext_ne("Previous Contributors"), "</heading>\n",
		})
		prepare_credits(hypertext, credits.previous_contributors)

		hypertext = table.concat(hypertext):sub(1, -2)

		-- Game Branding at the top left
		local fs = "image[1.9,0.3;1.5,1.5;" .. core.formspec_escape(game_logo) .. "]" ..
			"style_type[label;valign=center;halign=center]" ..
			"label[0.1,1.9;5.3,0.4;" .. core.formspec_escape(game_title) .. "]" ..
			"button_url[0.5,3.25;4.5,0.7;github;GitHub;https://github.com/GP-commits/OpenCodeCraft.git]" ..

			-- Engine details slightly smaller below
			"image[0.5,4.15;1.0,1.0;" .. core.formspec_escape(engine_logofile) .. "]" ..
			"label[1.6,4.45;3.5,0.4;" .. core.formspec_escape("Luanti " .. version.string) .. "]" ..

			"button_url[1.5,5.25;2.5,0.7;homepage;luanti.org;https://www.luanti.org/]"

		if PLATFORM == "Android" then
			fs = fs .. "button[0.5,2.45;4.5,0.7;share_debug;" .. fgettext("Share debug log") .. "]"
		else
			fs = fs .. "tooltip[userdata;" ..
					fgettext("Opens the directory that contains user-provided worlds, games, mods,\n" ..
							"and texture packs in a file manager / explorer.") .. "]"
			fs = fs .. "button[0.5,2.45;4.5,0.7;userdata;" .. fgettext("Open User Data Directory") .. "]"
		end

		local active_renderer_info = fgettext("Active renderer:") .. "\n" ..
			core.formspec_escape(get_renderer_info())
		fs = fs .. "style_type[textarea;valign=center]" ..
			"textarea[0.1,6.15;5.7,1;;" .. active_renderer_info .. ";]" ..
			"box[5.5,1.2;9.3,0.03;#cfd6e6]" ..
			"hypertext[5.5,0.25;9.75,6.6;credits;" .. core.formspec_escape(hypertext) .. "]"

		return fs
	end,

	cbf_button_handler = function(this, fields, name, tabdata)
		if fields.share_debug then
			local path = core.get_user_path() .. DIR_DELIM .. "debug.txt"
			core.share_file(path)
		end

		if fields.userdata then
			core.open_dir(core.get_user_path())
		end
	end,

	on_change = function(type)
		if type == "ENTER" then
			local game = pkgmgr.find_by_gameid(core.settings:get("menu_last_game")) or pkgmgr.games[1]
			if game then
				mm_game_theme.set_game(game)
			else
				mm_game_theme.set_engine()
			end
		end
	end,
}
