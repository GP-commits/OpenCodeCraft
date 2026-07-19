-- Luanti Edu: Robot Entity
-- A friendly programmable robot that students control via coding blocks.

local modpath = minetest.get_modpath("luanti_robot")

----------------------------------------------------------------------
-- Robot Entity Definition
----------------------------------------------------------------------
minetest.register_entity("luanti_robot:robot", {
    initial_properties = {
        physical = true,
        collide_with_objects = false,
        collisionbox = {-0.4, -0.5, -0.4, 0.4, 0.9, 0.4},
        visual = "mesh",
        mesh = "robot.obj",
        textures = {"robot.png"},
        visual_size = {x = 1, y = 1},
        makes_footstep_sound = true,
        static_save = true,
    },

    -- Robot's facing direction (0=North, 1=West, 2=South, 3=East)
    _dir = 0,

    -- Direction offset vectors
    _dir_vecs = {
        [0] = vector.new( 0, 0,  1),
        [1] = vector.new(-1, 0,  0),
        [2] = vector.new( 0, 0, -1),
        [3] = vector.new( 1, 0,  0),
    },

    on_activate = function(self, staticdata, dtime_s)
        self.object:set_armor_groups({immortal = 1})
        -- Restore direction from staticdata
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            if data then self._dir = data.dir or 0 end
        end
        self:_update_yaw()
    end,

    get_staticdata = function(self)
        return minetest.serialize({dir = self._dir})
    end,

    on_rightclick = function(self, clicker)
        local pname = clicker:get_player_name()
        minetest.chat_send_player(pname,
            "[Luanti Edu] Robot is ready! Place START block and coding blocks, then right-click START to run.")
    end,

    on_step = function(self, dtime)
        -- Keep robot upright
        local vel = self.object:get_velocity()
        if vel then
            self.object:set_velocity(vector.new(vel.x, vel.y, vel.z))
        end
    end,

    --------------------------------------------------------------------
    -- Robot Actions (called by the executor)
    --------------------------------------------------------------------

    _update_yaw = function(self)
        -- Convert direction index to yaw
        local yaw_map = {[0] = 0, [1] = math.pi/2, [2] = math.pi, [3] = -math.pi/2}
        self.object:set_yaw(yaw_map[self._dir] or 0)
    end,

    move_forward = function(self)
        local pos = self.object:get_pos()
        local dir_vec = self._dir_vecs[self._dir]
        local new_pos = vector.add(pos, dir_vec)

        -- Check if destination is walkable
        local node = minetest.get_node(new_pos)
        local node_def = minetest.registered_nodes[node.name]
        if node_def and node_def.walkable then
            -- Try to step up one block
            local up_pos = vector.add(new_pos, vector.new(0, 1, 0))
            local up_node = minetest.get_node(up_pos)
            local up_def = minetest.registered_nodes[up_node.name]
            if up_def and not up_def.walkable then
                new_pos = up_pos
            else
                return  -- blocked, can't move
            end
        else
            -- Check if we'd fall (drop down)
            local below = vector.add(new_pos, vector.new(0, -1, 0))
            local below_node = minetest.get_node(below)
            local below_def = minetest.registered_nodes[below_node.name]
            if below_def and not below_def.walkable then
                new_pos = below  -- step down
            end
        end

        self.object:set_pos(new_pos)
        -- Play movement animation/sound
        minetest.sound_play("robot_move", {object = self.object, gain = 0.5}, true)
    end,

    turn_left = function(self)
        self._dir = (self._dir + 1) % 4
        self:_update_yaw()
        minetest.sound_play("robot_turn", {object = self.object, gain = 0.3}, true)
    end,

    turn_right = function(self)
        self._dir = (self._dir - 1 + 4) % 4
        self:_update_yaw()
        minetest.sound_play("robot_turn", {object = self.object, gain = 0.3}, true)
    end,

    is_forward_clear = function(self)
        local pos = self.object:get_pos()
        local dir_vec = self._dir_vecs[self._dir]
        local check_pos = vector.add(pos, dir_vec)
        local node = minetest.get_node(check_pos)
        local node_def = minetest.registered_nodes[node.name]
        return node_def and not node_def.walkable
    end,

    place_block = function(self)
        local pos = self.object:get_pos()
        local dir_vec = self._dir_vecs[self._dir]
        local target = vector.add(pos, dir_vec)
        local node = minetest.get_node(target)
        local node_def = minetest.registered_nodes[node.name]
        if node_def and not node_def.walkable then
            minetest.set_node(target, {name = "default:stone"})
            minetest.sound_play("default_place_node_hard", {pos = target, gain = 0.5}, true)
        end
    end,

    dig_block = function(self)
        local pos = self.object:get_pos()
        local dir_vec = self._dir_vecs[self._dir]
        local target = vector.add(pos, dir_vec)
        local node = minetest.get_node(target)
        local node_def = minetest.registered_nodes[node.name]
        if node_def and node_def.walkable and node.name ~= "air" then
            minetest.remove_node(target)
            minetest.sound_play("default_dig_hard", {pos = target, gain = 0.5}, true)
        end
    end,
})

----------------------------------------------------------------------
-- Robot Spawner Node
-- Players right-click this to spawn a robot at that location.
----------------------------------------------------------------------
minetest.register_node("luanti_robot:spawner", {
    description = "Robot Spawner\nRight-click to place a programmable robot here!",
    tiles = {"robot_spawner.png"},
    groups = {cracky = 1},
    is_ground_content = false,
    on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
        local pname = clicker:get_player_name()
        local spawn_pos = vector.add(pos, vector.new(0, 1, 0))
        -- Check if there is already a robot nearby
        local objs = minetest.get_objects_inside_radius(spawn_pos, 2)
        for _, obj in ipairs(objs) do
            local ent = obj:get_luaentity()
            if ent and ent.name == "luanti_robot:robot" then
                minetest.chat_send_player(pname,
                    "[Luanti Edu] A robot already exists here!")
                return itemstack
            end
        end
        minetest.add_entity(spawn_pos, "luanti_robot:robot")
        minetest.chat_send_player(pname,
            "[Luanti Edu] Robot spawned! Now build your program with coding blocks and right-click the START block.")
        return itemstack
    end,
})

minetest.register_craft({
    output = "luanti_robot:spawner",
    recipe = {
        {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
        {"default:steel_ingot", "default:mese_crystal",  "default:steel_ingot"},
        {"default:steel_ingot", "default:steel_ingot", "default:steel_ingot"},
    },
})

minetest.log("action", "[luanti_robot] Loaded!")
