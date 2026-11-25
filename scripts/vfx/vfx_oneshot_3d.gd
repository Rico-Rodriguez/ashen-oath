class_name VfxOneshot3D
extends Node3D

var lifetime: float = 1.0
var on_tick: Callable

var _elapsed: float = 0.0


func configure(max_lifetime: float, tick_fn: Callable = Callable()) -> void:
	lifetime = maxf(max_lifetime, 0.05)
	on_tick = tick_fn


func _process(delta: float) -> void:
	_elapsed += delta
	var t01 := clampf(_elapsed / lifetime, 0.0, 1.0)
	if on_tick.is_valid():
		on_tick.call(t01, _elapsed)
	if _elapsed >= lifetime:
		queue_free()
