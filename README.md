# Godot-Kicker

Procedural hockey rink with editable terrain, ball physics, and goal detection.

## Features
- **TerrainGeneration**
  - Flat terrain, quad editing, forbidden zones
  - Ball-safe: ball won't get stuck in the terrain
  - Reset function
- **TerrainEditor**
  - Mouse + Q/E for height editing
  - Signal emitted when terrain is edited for updates
- **Ball**
  - Physics: mass, damping, bounce/friction
  - Limited falling speed
- **Rink / Goals**
  - Walls and goals for the field
  - Area3D nodes monitor goal events
- **Camera**
  - WASD: Move
  - Shift: Lower
  - Space: Raise

## Controls
| Action                       | Keyboard / Mouse      |
|------------------------------|-----------------------|
| Select quad                  | Left click            |
| Raise quad                   | Q                     |
| Lower quad                   | E                     |
| Move camera                  | WASD                  |
| Raise camera                 | Space                 |
| Lower camera                 | Shift                 |

## Exe
- Download 'export' folder
- keep both Godot-kicker.exe and Godot-kicker.pck in the same folder
- run Godot-kicker.exe

