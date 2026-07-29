# OpenClassCraft Teacher Console

The Teacher Console is a local desktop application for classroom planning and assessment. It is separate from the Luanti-derived game code and stores its data on the teacher's computer.

## Current workflows

- Create lessons with objectives and checkpoints.
- Maintain students, groups, and group-to-lesson/world assignments.
- Import a CSV class list with a required `Name` column and optional `Group` column.
- Track checkpoints, add teacher notes, export CSV reports, and create JSON backups.
- Share the selected lesson with a local OpenClassCraft host through a loopback-only bridge.

## LAN lesson bridge

1. In **Classroom**, create a lesson assignment and choose it under **LAN lesson bridge**.
2. Click **Start bridge**, then click **Export settings**.
3. Copy the generated `openclasscraft_teacher_bridge.conf` entries into the teacher host's `minetest.conf`.
4. Restart the OpenClassCraft host.
5. In the hosted world, an educator runs `/occ_teacher_sync`.

The bridge listens only on `127.0.0.1`, requires the generated token, and returns the active lesson plan only. The game can also send a completed checkpoint back to the Console using the same token. It does not transmit student records, reports, or backups.

## Development

Run `npm start` on Windows. Build an unpacked Windows app with `npx electron-builder --win dir`.
