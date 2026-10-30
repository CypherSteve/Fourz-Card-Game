class_name TestScenes
extends RefCounted

## Automated test suite for scene compilation, script parsing, and node instantiation.

static func run() -> bool:
	print("--- Running TestScenes ---")
	var success: bool = true
	
	var scenes_to_test: Array[String] = [
		"res://src/presentation/main_menu.tscn",
		"res://src/presentation/table_view.tscn",
		"res://src/presentation/card_view.tscn",
		"res://src/presentation/opponent_view.tscn",
		"res://src/presentation/multiplayer_modal.tscn",
		"res://src/presentation/game_over_modal.tscn",
		"res://src/presentation/burn_vfx.tscn",
		"res://src/presentation/swap_overlay.tscn"
	]
	
	for scene_path in scenes_to_test:
		var packed_scene = load(scene_path) as PackedScene
		if packed_scene == null:
			printerr("  [FAIL] Failed to load PackedScene: ", scene_path)
			success = false
			continue
		
		var instance = packed_scene.instantiate()
		if instance == null:
			printerr("  [FAIL] Failed to instantiate PackedScene: ", scene_path)
			success = false
			continue
		
		# Scene instantiated successfully without parse/script errors
		instance.free()
		print("  [PASS] Successfully compiled and instantiated: ", scene_path.get_file())
	
	# Verify all standalone scripts parse and load cleanly
	var scripts_to_test: Array[String] = [
		"res://src/core/card_data.gd",
		"res://src/core/deck.gd",
		"res://src/core/player_state.gd",
		"res://src/core/game_state.gd",
		"res://src/core/game_rules.gd",
		"res://src/core/game_engine.gd",
		"res://src/ai/bot_strategy.gd",
		"res://src/ai/bot_controller.gd",
		"res://src/network/network_manager.gd",
		"res://src/presentation/audio_manager.gd",
		"res://src/presentation/main_menu.gd",
		"res://src/controllers/player_controller.gd"
	]
	
	for script_path in scripts_to_test:
		var script = load(script_path)
		if script == null:
			printerr("  [FAIL] Failed to load GDScript: ", script_path)
			success = false
			continue
		print("  [PASS] Successfully parsed GDScript: ", script_path.get_file())
		
	if success:
		print("  [PASS] TestScenes completed successfully.")
	else:
		printerr("  [FAIL] TestScenes encountered errors.")
		
	return success
