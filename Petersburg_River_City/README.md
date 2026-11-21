# Petersburg: River City

An original, offline Godot 4.2+ first-person neighborhood game inspired by Petersburg, Virginia. It is fictionalized and does not reproduce real addresses or maps.

## Open the project

1. Install Godot 4.2 or newer.
2. Use **Import** and select `project.godot`.
3. Open `scenes/main.tscn` and press **F6** or **F5**.
4. Use Forward+ on modern hardware or Compatibility for older phones/PCs.

## Controls

- WASD: move
- Shift: sprint
- Space: jump
- Mouse: look
- E: interact / enter nearby car
- F: exit car
- R: restart
- Esc: unlock mouse
- Android: left-side touch joystick and right-side drag to look; on-screen buttons appear automatically.

## Play

Walk to the gold crate at approximately `(-18, 0, -15)`, aim at it, and press E. Carry or drive to the green drop-off around `(0, 0, 30)` before the 180-second timer expires. Completing delivery adds local cash and starts a fresh mission. Cash is stored only in `user://petersburg_save.json`.

## Included

- Procedural Old Towne-style neighborhood, streets, brick buildings, waterfront, and riverwalk
- First-person walking, sprinting, jumping, mouse look, and basic touchscreen controls
- Enterable/exit-able vehicle with forward/reverse and steering
- Timed package mission and local save
- Original fictional UI and environments

## Important implementation note

The first-pass vehicle uses Godot `VehicleBody3D`; movement tuning is intentionally basic. The runnable source is complete, but this container does not include a Godot executable, so I could not start the engine or visually verify it here. Open and test it with Godot 4.2+.
