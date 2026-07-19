-- OpenClassCraft world styling.
-- Adds bright, chunky voxel trees and classroom-friendly ground decoration
-- to newly generated chunks.

local rng_seed = 73451

local ground_nodes = {
	["default:dirt_with_grass"] = true,
	["default:dirt_with_rainforest_litter"] = true,
	["default:dirt_with_coniferous_litter"] = true,
}

local dry_ground_nodes = {
	["default:dry_dirt_with_dry_grass"] = true,
	["default:dirt_with_dry_grass"] = true,
}

local decorative_ground_nodes = {
	["default:sand"] = true,
	["default:desert_sand"] = true,
	["default:silver_sand"] = true,
	["default:snowblock"] = true,
	["default:snow"] = true,
	["default:stone"] = true,
}

local leaves_by_trunk = {
	["default:tree"] = "default:leaves",
	["default:jungletree"] = "default:jungleleaves",
	["default:pine_tree"] = "default:pine_needles",
	["default:acacia_tree"] = "default:acacia_leaves",
	["default:aspen_tree"] = "default:aspen_leaves",
}

local flower_nodes = {
	"openclasscraft_world:flower_yellow",
	"openclasscraft_world:flower_pink",
	"openclasscraft_world:flower_blue",
	"openclasscraft_world:flower_orange",
}

local micro_nodes = {
	"openclasscraft_world:micro_stone",
}

local shore_micro_nodes = {
	"openclasscraft_world:micro_sand",
	"openclasscraft_world:micro_stone",
}

local ambient_music_handles = {}
local ambient_music_name = "openclasscraft_ambient_learning_loop"

local function stop_ambient_music(player_name)
	local handle = ambient_music_handles[player_name]
	if handle then
		minetest.sound_stop(handle)
		ambient_music_handles[player_name] = nil
	end
end

local function start_ambient_music(player)
	local player_name = player:get_player_name()
	stop_ambient_music(player_name)
	ambient_music_handles[player_name] = minetest.sound_play(ambient_music_name, {
		to_player = player_name,
		gain = 0.28,
		loop = true,
		fade = 1.5,
	}, true)
end

local function can_replace(pos)
	local node = minetest.get_node_or_nil(pos)
	if not node then
		return false
	end
	return node.name == "air" or minetest.get_item_group(node.name, "flora") > 0 or
		minetest.get_item_group(node.name, "grass") > 0 or
		minetest.get_item_group(node.name, "dry_grass") > 0
end

local function place_if_clear(pos, name)
	if can_replace(pos) then
		minetest.set_node(pos, {name = name})
	end
end

local function place_if_air(pos, name, param2)
	local node = minetest.get_node_or_nil(pos)
	if node and node.name == "air" then
		minetest.set_node(pos, {name = name, param2 = param2 or 0})
	end
end

local function find_surface(x, z, min_y, max_y)
	for y = max_y, min_y, -1 do
		local pos = {x = x, y = y, z = z}
		local node = minetest.get_node_or_nil(pos)
		if node and (ground_nodes[node.name] or dry_ground_nodes[node.name] or decorative_ground_nodes[node.name]) then
			local above = {x = x, y = y + 1, z = z}
			if can_replace(above) then
				return pos, node.name
			end
		end
	end
	return nil
end

local function build_chunky_canopy(center, leaf, radius, height)
	for dy = -1, height do
		local layer_radius = radius
		if dy == height then
			layer_radius = math.max(1, radius - 1)
		elseif dy == -1 then
			layer_radius = math.max(1, radius - 1)
		end

		for dx = -layer_radius, layer_radius do
			for dz = -layer_radius, layer_radius do
				local edge = math.abs(dx) == layer_radius and math.abs(dz) == layer_radius
				local corner_skip = edge and dy ~= 0
				if not corner_skip then
					place_if_clear({
						x = center.x + dx,
						y = center.y + dy,
						z = center.z + dz,
					}, leaf)
				end
			end
		end
	end
end

local function build_tree(base, trunk, pr)
	local leaf = leaves_by_trunk[trunk] or "default:leaves"
	local height = pr:next(5, 8)
	local radius = pr:next(2, 3)

	for y = 1, height do
		minetest.set_node({x = base.x, y = base.y + y, z = base.z}, {name = trunk})
	end

	local crown = {x = base.x, y = base.y + height, z = base.z}
	build_chunky_canopy(crown, leaf, radius, pr:next(2, 3))

	if pr:next(1, 3) == 1 then
		build_chunky_canopy({x = base.x + pr:next(-1, 1), y = base.y + height - 1, z = base.z + pr:next(-1, 1)},
			leaf, math.max(1, radius - 1), 1)
	end

	for _ = 1, pr:next(3, 7) do
		place_if_air({
			x = base.x + pr:next(-radius - 1, radius + 1),
			y = base.y + height + pr:next(-1, 2),
			z = base.z + pr:next(-radius - 1, radius + 1),
		}, "openclasscraft_world:micro_leaf", pr:next(0, 23))
	end
end

local function place_flower_cluster(surface, pr)
	local flower = flower_nodes[pr:next(1, #flower_nodes)]
	local radius = pr:next(1, 3)
	for dx = -radius, radius do
		for dz = -radius, radius do
			if pr:next(1, 100) <= 55 then
				local pos = {x = surface.x + dx, y = surface.y + 1, z = surface.z + dz}
				local below = minetest.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
				if below and ground_nodes[below.name] then
					place_if_clear(pos, flower)
				end
			end
		end
	end
end

local function place_grass(surface, ground, pr)
	local is_dry = dry_ground_nodes[ground]
	local prefix = is_dry and "default:dry_grass_" or "default:grass_"
	local count = pr:next(2, 5)
	for _ = 1, count do
		local pos = {
			x = surface.x + pr:next(-2, 2),
			y = surface.y + 1,
			z = surface.z + pr:next(-2, 2),
		}
		local below = minetest.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
		if below and (ground_nodes[below.name] or dry_ground_nodes[below.name]) then
			place_if_clear(pos, prefix .. pr:next(3, 5))
		end
	end
end

local function place_micro_cluster(surface, ground, pr)
	local nodes = decorative_ground_nodes[ground] and shore_micro_nodes or micro_nodes
	local count = pr:next(3, 8)
	for _ = 1, count do
		local pos = {
			x = surface.x + pr:next(-3, 3),
			y = surface.y + 1,
			z = surface.z + pr:next(-3, 3),
		}
		local below = minetest.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
		if below and (ground_nodes[below.name] or dry_ground_nodes[below.name] or decorative_ground_nodes[below.name]) then
			place_if_air(pos, nodes[pr:next(1, #nodes)], pr:next(0, 23))
		end
	end
end

for _, def in ipairs({
	{"flower_yellow", "Yellow Learning Flower", "openclasscraft_flower_yellow.png"},
	{"flower_pink", "Pink Learning Flower", "openclasscraft_flower_pink.png"},
	{"flower_blue", "Blue Learning Flower", "openclasscraft_flower_blue.png"},
	{"flower_orange", "Orange Learning Flower", "openclasscraft_flower_orange.png"},
}) do
	minetest.register_node("openclasscraft_world:" .. def[1], {
		description = def[2],
		drawtype = "plantlike",
		waving = 1,
		tiles = {def[3]},
		inventory_image = def[3],
		wield_image = def[3],
		paramtype = "light",
		sunlight_propagates = true,
		walkable = false,
		buildable_to = true,
		groups = {snappy = 3, flora = 1, attached_node = 1, dig_immediate = 3},
		sounds = default.node_sound_leaves_defaults(),
		selection_box = {
			type = "fixed",
			fixed = {-0.25, -0.5, -0.25, 0.25, 0.2, 0.25},
		},
	})
end

local function register_micro_block(name, description, texture, box)
	minetest.register_node("openclasscraft_world:" .. name, {
		description = description,
		drawtype = "nodebox",
		tiles = {texture},
		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		walkable = false,
		buildable_to = true,
		groups = {snappy = 3, oddly_breakable_by_hand = 3, attached_node = 1, dig_immediate = 3},
		sounds = default.node_sound_leaves_defaults(),
		node_box = {
			type = "fixed",
			fixed = box,
		},
		selection_box = {
			type = "fixed",
			fixed = box,
		},
	})
end

register_micro_block("micro_grass_small", "Small Bright Grass Block", "default_grass.png", {
	-0.28, -0.5, -0.28, 0.18, -0.32, 0.18,
})
register_micro_block("micro_grass_medium", "Medium Bright Grass Block", "default_grass.png", {
	-0.38, -0.5, -0.38, 0.34, -0.24, 0.34,
})
register_micro_block("micro_leaf", "Small Leaf Block", "default_leaves.png", {
	-0.28, -0.46, -0.28, 0.28, -0.06, 0.28,
})
register_micro_block("micro_dirt", "Small Dirt Block", "default_dirt.png", {
	-0.26, -0.5, -0.26, 0.26, -0.26, 0.26,
})
register_micro_block("micro_stone", "Small Stone Block", "default_stone.png", {
	-0.22, -0.5, -0.22, 0.22, -0.30, 0.22,
})
register_micro_block("micro_sand", "Small Sand Block", "default_sand.png", {
	-0.34, -0.5, -0.34, 0.24, -0.30, 0.24,
})

minetest.register_lbm({
	label = "Remove old OpenClassCraft ground micro blocks",
	name = "openclasscraft_world:remove_old_floating_micro_blocks",
	nodenames = {
		"openclasscraft_world:micro_grass_small",
		"openclasscraft_world:micro_grass_medium",
		"openclasscraft_world:micro_dirt",
		"openclasscraft_world:micro_leaf",
	},
	run_at_every_load = true,
	action = function(pos)
		local below = minetest.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
		if below and (ground_nodes[below.name] or dry_ground_nodes[below.name] or decorative_ground_nodes[below.name]) then
			minetest.remove_node(pos)
		end
	end,
})

minetest.register_on_generated(function(minp, maxp, blockseed)
	if maxp.y < 0 or minp.y > 80 then
		return
	end

	local pr = PseudoRandom(blockseed + rng_seed)
	local attempts = math.max(8, math.floor(((maxp.x - minp.x + 1) * (maxp.z - minp.z + 1)) / 80))

	for _ = 1, attempts do
		local x = pr:next(minp.x + 2, maxp.x - 2)
		local z = pr:next(minp.z + 2, maxp.z - 2)
		local surface, ground = find_surface(x, z, math.max(minp.y, -8), math.min(maxp.y, 80))

		if surface then
			local roll = pr:next(1, 100)
			if ground_nodes[ground] and roll <= 13 then
				local trunks = {"default:tree", "default:aspen_tree", "default:pine_tree"}
				build_tree(surface, trunks[pr:next(1, #trunks)], pr)
			elseif dry_ground_nodes[ground] and roll <= 9 then
				build_tree(surface, "default:acacia_tree", pr)
			elseif roll <= 54 then
				place_grass(surface, ground, pr)
			elseif ground_nodes[ground] and roll <= 68 then
				place_flower_cluster(surface, pr)
			elseif roll <= 88 then
				place_micro_cluster(surface, ground, pr)
			end
		end
	end
end)

minetest.register_on_joinplayer(function(player)
	minetest.after(2, function()
		if player and player:is_player() then
			start_ambient_music(player)
		end
	end)
end)

minetest.register_on_leaveplayer(function(player)
	stop_ambient_music(player:get_player_name())
end)

minetest.register_chatcommand("music", {
	description = "Restart the OpenClassCraft background music",
	func = function(name)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player is not online."
		end
		start_ambient_music(player)
		return true, "OpenClassCraft background music restarted."
	end,
})

minetest.log("action", "[openclasscraft_world] Bright world decorations loaded")
