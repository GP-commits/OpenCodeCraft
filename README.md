# OpenClassCraft

![OpenClassCraft Logo](games/luanti_edu/menu/icon.png)

OpenClassCraft is a classroom-focused voxel coding game built for students, teachers, and hands-on programming lessons. It turns programming into something students can see and touch: players place coding blocks in the world, connect them to a START block, and run those instructions through a programmable robot.

The goal is simple: make programming concepts feel immediate. Students learn sequencing, direction, loops, conditions, debugging, and problem solving inside a familiar block world instead of starting from a blank code editor.

## OpenClassCraft vs Standard Luanti

OpenClassCraft is not just a renamed Luanti build. It is a learning-focused game experience made on top of the Luanti engine. Standard Luanti and Minetest are general-purpose voxel engines/platforms; OpenClassCraft is a ready-to-play educational coding game.

| Area | Standard Luanti / Minetest | OpenClassCraft |
| --- | --- | --- |
| Purpose | General sandbox engine/game platform | Education-focused coding game |
| Learning flow | Depends on external mods/games | Built-in block-programming flow |
| Programming | Usually text/mod based | Physical in-world coding blocks |
| Robot | Not included by default | Programmable robot with movement/action logic |
| Coding blocks | Not included by default | START, Move, Turn, Loop, If, Else, While, Variable, Sensor, Wait, Place, Dig, and Stop blocks |
| Classroom guidance | Depends on external mods or manual signs | Editable guide NPCs and chalkboards for lesson goals, instructions, and reference links |
| Player roles | Generic players | Student, educator, and professor/host roles |
| Inventory | Standard inventory and crafting | Simplified lesson-friendly inventory |
| Accessibility | Uses the normal engine UI settings | Dyslexia-friendly font option, read-aloud helper messages, high contrast, simplified controls, colorblind support, and large UI mode |
| Networking | Standard multiplayer screens | Local classroom server join flow |
| Target audience | Players, modders, server owners | Students, teachers, workshops, and coding clubs |

## Key Differences

- OpenClassCraft focuses on programming education instead of open-ended sandbox play.
- Students learn sequencing, loops, conditions, and algorithms by placing blocks in the world.
- Educators can place guide NPCs and chalkboards directly in the world for lesson instructions and reference links.
- The interface is intentionally simpler so students can start learning faster.
- Accessibility options are built into settings for classrooms that need clearer fonts, larger UI, higher contrast, colorblind-friendly colors, simplified controls, and read-aloud helper text.

## How To Play

1. Start OpenClassCraft.
2. Create or select a world.
3. Spawn a robot using the Robot Spawner.
4. Place a START block.
5. Connect movement and logic blocks to the right of the START block.
6. Right-click START to run the robot program.

## Robot Programming

The robot follows connected blocks in order. Use movement blocks to move forward or turn, and logic blocks to build simple algorithms. Current programming blocks include START, Move Forward, Turn Left, Turn Right, Loop, If, Else, While, Variable, Sensor, Wait, Place Block, Dig Block, and Stop. If no blocks are connected to START, the game will ask you to add instructions.

## Accessibility

OpenClassCraft includes classroom accessibility settings:

- Dyslexia-friendly font
- Read aloud helpers
- High contrast UI
- Simplified controls
- Colorblind support
- Large UI mode

## Educator Use

Educators can host a world for students and use the professor skin by default. The main menu includes an Educator option and local server joining controls for classroom play.

Educator classroom tools include:

- Guide NPCs that teachers can place as in-world helpers for students. They can show instructions, extra information, and an active reference link.
- Chalkboards for posting learning goals, lesson notes, and explicit task instructions inside the world.

## Windows Build

The Windows executable is built as:

```text
bin/Release/openclasscraft.exe
```

Required runtime DLLs should stay beside the executable in `bin/Release`.

## Project

Repository:

```text
https://github.com/GP-commits/OpenCodeCraft.git
```

## Credits

OpenClassCraft was created by Sivadarsh P Dinesh as an educational coding game experience.

Built on the Luanti engine.
