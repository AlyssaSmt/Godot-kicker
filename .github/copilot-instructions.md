# Copilot / AI Agent Instructions for Godot-kicker

Purpose: Help an AI coding agent become productive quickly in this Godot 4.5 project.

**Big Picture**
- Godot 4.5 single-game project. Main orchestration happens in `main/main.gd` and scene `game.tscn`.
- Networking: `autoload/Net.gd` is the canonical networking singleton (ENet). `net/NetworkManager.gd` is a helper class.
- Gameplay flow: `MatchManager.gd` controls rounds/timer; `ScoreManager.gd` holds scores; `TurnManager` controls player turns. `Main` resets ball/field and reacts to goals.
- Physics objects: Ball is in group `ball`. Goals use Area3D detectors (see `Goal/GoalDetector.gd`).

**Authority & RPC patterns**
- Host/server is authoritative for game state (scores, resets). Check `Net.is_host()` or `multiplayer.is_server()` before mutating authoritative state.
- RPC decorators used across codebase: e.g. `@rpc("authority","reliable","call_local")` and `@rpc("any_peer","reliable")`. Follow existing usage patterns when adding RPCs.
- Typical pattern: host updates state -> `rpc(...)` to replicate to all peers (includes host via `call_local`). Example: `_on_goal_scored` in `main/main.gd`.

**Key files to inspect (quick links)**
- `project.godot` (autoload: `Net.gd`, engine config)
- `autoload/Net.gd` (primary multiplayer interface and player lobby logic)
- `net/NetworkManager.gd` (ENet helper, connect signals)
- `main/main.gd` (game orchestration: resets, UI toggles, goal handling)
- `MatchManager.gd` (round timer and UI hooks)
- `ScoreManager/ScoreManager.gd` (score storage and reset logic)
- `Ball/Ball.gd` (ball physics behavior)

**Developer workflows / run instructions**
- Recommended: open project in Godot 4.5 editor. The project file shows `config/features` includes "4.5".
- Run locally: open `game.tscn` or use the editor Run button. From CLI (if you have Godot installed):

```powershell
godot --path .
```

- Quick multiplayer testing: start one instance as host from the editor, then in a second editor instance call in the Remote Console:

```gdscript
Net.host(12345, "HostName")
Net.join("127.0.0.1", 12345, "ClientName")
```

**Project-specific conventions**
- Group names matter: `ball` group nodes are reset by the Main script. Use `get_tree().get_first_node_in_group("ball")` when referencing the ball.
- UI methods are duck-typed. `MatchManager` uses `has_method()` checks (e.g., `start_match_ui`, `set_time_left`). When updating UI, prefer calling those methods if present.
- Score access is defensive: `MatchManager._get_scores()` prefers getter methods, then falls back to common property names (`score_left`, `left_score`, `blue_score`, ...).

**Integration & debugging tips**
- Use the Godot Remote Inspector and Remote Console to call autoload functions (`Net.host`, `Net.join`) and inspect `Net.players`.
- Search for `rpc(`, `@rpc(` and `multiplayer.multiplayer_peer` to find network-sensitive code when making changes.
- Watch for inconsistent team naming: `Net.gd` uses both `"Blue"/"Red"` and `"A"/"B"` in different places — be careful when modifying team-related logic.

If anything is unclear or you want more detail (specific files, extra examples, or conventions), say which area to expand and I'll iterate.
