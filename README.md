# Godot-Kicker

Procedurales Hockey-Spielfeld mit editierbarem Terrain, Ball-Physik und Goal-Detection.

## Features
- **TerrainGeneration**
  - Flaches Terrain, Quad-Bearbeitung, Forbidden Zones
  - Ball-Safe: Ball hängt nicht im Terrain fest
  - Reset-Funktion
- **TerrainEditor**
  - Maus + Q/E zur Höhenbearbeitung
  - Signal zu bearbeitetem Terrain für Updates
- **Ball**
  - Physik: Masse, Dämpfung, Bounce/Friction
  - Begrenzte Fallgeschwindigkeit
- **Rink / Tore**
  - Wände und Toore fürs Spielfeld
  - Area3D Nodes überwachen Treffer
- **Kamera**
  - WASD: Move
  - Shift: Senken
  - Space: Heben

## Steuerung
| Aktion                       | Tastatur / Maus        |
|-------------------------------|----------------------|
| Quad auswählen                | Linksklick            |
| Quad erhöhen                  | Q                     |
| Quad senken                   | E                     |
| Kamera bewegen                | WASD                  |
| Kamera heben                  | Space                 |
| Kamera senken                 | Shift                 |

## ToDo / Verbesserungen
- Multiplayer Implementierung
- UI für Steuerung und Tore
- Undo / Redo / Timer für Terrain-Editing
- Terrain-Editing beeinflusst Rink und Tore
- Terrainfarbenveränderung nach Höhe 
