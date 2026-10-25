class_name TestRunner
extends SceneTree

const TestNetwork = preload("res://src/tests/test_network.gd")
const TestScenes = preload("res://src/tests/test_scenes.gd")

func _init() -> void:
	print("\n==========================================")
	print("       FOURS CARD GAME - TEST RUNNER      ")
	print("==========================================\n")
	
	var all_passed: bool = true
	
	if not TestScenes.run():
		all_passed = false
	
	if not TestDeck.run():
		all_passed = false
	
	if not TestRules.run():
		all_passed = false
		
	if not TestEngine.run():
		all_passed = false

	if not TestBot.run():
		all_passed = false
	
	if not TestNetwork.run():
		all_passed = false
	
	print("\n==========================================")
	if all_passed:
		print("  ALL TESTS PASSED SUCCESSFULLY! (100%)  ")
	else:
		print("  SOME TESTS FAILED!                     ")
	print("==========================================\n")
	
	quit(0 if all_passed else 1)
