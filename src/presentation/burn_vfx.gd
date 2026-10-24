class_name BurnVFX
extends Control

## BurnVFX: Visual effect trigger for pile burns (10 played or 4-of-a-kind).
## Creates screen shake, ember explosions, and dramatic celebratory text.

@onready var label: Label = $Label

func _ready() -> void:
	visible = false

func play_burn_effect(reason_text: String) -> void:
	visible = true
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.5, 0.5)
	pivot_offset = size / 2.0
	label.text = "🔥 %s 🔥" % [reason_text]
	
	var tween := create_tween().set_parallel(true)
	# Fade in and scale punch
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Settle back to normal size
	var seq := create_tween()
	seq.tween_interval(0.2)
	seq.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	seq.tween_interval(1.2)
	seq.tween_property(self, "modulate:a", 0.0, 0.4)
	seq.tween_callback(func() -> void:
		visible = false
	)
