-- Luanti Edu: Give Initial Stuff
-- Gives every new player starter tools + all coding blocks on first join.

local STARTER_ITEMS = {
    -- Starter tools. These use diamond-level capabilities but appear as normal tools.
    "default:pick_diamond",
    "default:axe_diamond",
    "default:shovel_diamond",

    -- Robot Spawner
    "luanti_robot:spawner",
    "openclasscraft_classroom:guide_npc_spawner",
    "openclasscraft_classroom:chalkboard",

    -- All Coding Blocks (5 of each)
    "luanti_coding:start",
    "luanti_coding:move_forward 5",
    "luanti_coding:turn_left 5",
    "luanti_coding:turn_right 5",
    "luanti_coding:loop 5",
    "luanti_coding:if_clear 5",
    "luanti_coding:else_block 5",
    "luanti_coding:while_clear 5",
    "luanti_coding:variable 5",
    "luanti_coding:sensor 5",
    "luanti_coding:wait 5",
    "luanti_coding:place_block 5",
    "luanti_coding:dig_block 5",
    "luanti_coding:stop 5",
    "luanti_coding:wire 16",
}

local function give_stuff(player)
    local inv = player:get_inventory()
    for _, item in ipairs(STARTER_ITEMS) do
        local stack = ItemStack(item)
        if inv:room_for_item("main", stack) then
            inv:add_item("main", stack)
        end
    end
    minetest.chat_send_player(player:get_player_name(),
        "=== Welcome to Luanti Edu! ===\n" ..
        "You have been given:\n" ..
        "  - Pickaxe, Axe, and Shovel\n" ..
        "  - A Robot Spawner\n" ..
        "  - Guide NPC and Chalkboard\n" ..
        "  - All Programming Blocks\n" ..
        "Place the Robot Spawner, right-click to spawn your robot,\n" ..
        "then place a START block and connect programming blocks to the right!\n" ..
        "Right-click the START block to run your program."
    )
end

-- Track which players have already received their starter kit
local given = {}

minetest.register_on_joinplayer(function(player)
    local pname = player:get_player_name()
    -- Only give items once per world (stored in player meta)
    local meta = player:get_meta()
    if meta:get_int("initial_stuff_given") == 1 then return end
    -- Small delay to let inventory load
    minetest.after(1, function()
        if player and player:is_player() then
            give_stuff(player)
            meta:set_int("initial_stuff_given", 1)
        end
    end)
end)

-- Command to re-give items if needed
minetest.register_chatcommand("givetools", {
    description = "Re-give starter tools and coding blocks",
    func = function(name)
        local player = minetest.get_player_by_name(name)
        if player then
            give_stuff(player)
            return true, "Starter items given!"
        end
        return false, "Player not found"
    end,
})

minetest.log("action", "[give_initial_stuff] Loaded!")
