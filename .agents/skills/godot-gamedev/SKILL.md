---
name: godot-gamedev
description: Activates when the user is developing, refactoring, or architecting video games, especially using the Godot Engine and GDScript.
---

# Godot & Game Development Best Practices

## Core Architecture Principles
* **Composition Over Inheritance:** Prefer building scenes with highly modular, single-responsibility nodes over deep script inheritance structures.
* **Signals Up, Methods Down:** Parent nodes should call methods directly on children. Child nodes should emit signals to communicate upwards or across systems to avoid tight coupling.
* **Node Autoloads (Singletons):** Limit Autoloads to globally persistent data structures (e.g., GameManager, PlayerStats, AudioManager, SaveSystem). Do not store fragile scene-state data there.

## GDScript Formatting & Performance
* **Static Typing:** Always use explicit type hints for variables, arguments, and return types (e.g., `var health: int = 100`, `func take_damage(amount: float) -> void`).
* **Onready Variables:** Cache node references using `@onready var sprite: Sprite2D = $Sprite2D` instead of fetching them continuously inside processing loops.
* **Avoid GC Overhead:** Use `queue_free()` to safely remove nodes from the tree at the end of the current frame instead of forcing instant deletions.
* **Delta Scaling:** Ensure frame-rate independent movement by multiplying physics updates by `delta` inside `_process` or `_physics_process`.

## Workflow & Deliverables
* Provide code snippets strictly using Godot 4+ syntax unless Godot 3 is explicitly requested.
* Organize project structures using a modular folder system (e.g., grouping the `.tscn`, `.gd`, and assets of a single entity into one folder like `scenes/player/`).
