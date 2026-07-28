# OpenClassCraft Creator

OpenClassCraft Creator is the separate desktop visual-mod editor for OpenClassCraft.

It uses draggable Blockly blocks to create a classroom block and safe interaction behavior. Export writes a self-contained OpenClassCraft mod folder with `mod.conf`, project data, and generated Lua. The editor only emits actions available through its visual palette.

## Run for development

```powershell
npm install
npm start
```

## Build a Windows app

```powershell
npm run package:win
```

The first local Windows build is in `dist/win-unpacked/OpenClassCraft Creator.exe`.
