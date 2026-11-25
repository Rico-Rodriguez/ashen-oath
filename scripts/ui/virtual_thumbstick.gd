class_name VirtualThumbstick
extends Control

signal move_vector_changed(vec: Vector2)

const MAX_RADIUS: float = 64.0
const DEADZONE_PX: float = 8.0

@export var floating: bool = true

var is_right_side: bool = false
var safe_bottom: float = 0.0

var _active: bool = false
var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO
var _output: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func reset_stick() -> void:
	_active = false
	_touch_index = -1
	_output = Vector2.ZERO
	move_vector_changed.emit(Vector2.ZERO)
	queue_redraw()


func _idle_center() -> Vector2:
	var pad := 114.0
	var y_pos := maxf(pad, size.y - pad - safe_bottom)
	var x_pos := (size.x - pad) if is_right_side else pad
	return Vector2(x_pos, y_pos)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and not _active:
			_active = true
			_touch_index = st.index
			_origin = st.position if floating else _idle_center()
			_current = st.position
			_update_output()
			accept_event()
		elif not st.pressed and _active and st.index == _touch_index:
			reset_stick()
			accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _active and sd.index == _touch_index:
			_current = sd.position
			_update_output()
			accept_event()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not _active:
				_active = true
				_touch_index = -99
				_origin = mb.position if floating else _idle_center()
				_current = mb.position
				_update_output()
				accept_event()
			elif not mb.pressed and _active and _touch_index == -99:
				reset_stick()
				accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _active and _touch_index == -99:
			_current = mm.position
			_update_output()
			accept_event()


func _update_output() -> void:
	var delta := _current - _origin
	var dist := delta.length()
	if dist > MAX_RADIUS:
		delta = (delta / dist) * MAX_RADIUS
		_current = _origin + delta
	if dist < DEADZONE_PX:
		_output = Vector2.ZERO
	else:
		var t := clampf((dist - DEADZONE_PX) / (MAX_RADIUS - DEADZONE_PX), 0.0, 1.0)
		_output = (delta / dist) * t
	move_vector_changed.emit(_output)
	queue_redraw()


func _draw() -> void:
	var center := _origin if _active else _idle_center()
	var ring_alpha := 0.72 if _active else 0.28
	var fill_alpha := 0.34 if _active else 0.11

	draw_circle(center, MAX_RADIUS, Color(0.045, 0.052, 0.072, fill_alpha))
	draw_arc(center, MAX_RADIUS, 0.0, TAU, 56, Color(0.78, 0.62, 0.33, ring_alpha), 2.5, true)
	draw_arc(center, MAX_RADIUS * 0.60, 0.0, TAU, 40, Color(0.62, 0.49, 0.26, ring_alpha * 0.55), 1.4, true)

	var tick_col := Color(0.84, 0.68, 0.36, ring_alpha * 0.65)
	for i in range(4):
		var a := float(i) * (PI * 0.5)
		var dir := Vector2(cos(a), sin(a))
		draw_line(center + dir * (MAX_RADIUS - 8.0), center + dir * (MAX_RADIUS - 1.5), tick_col, 1.8, true)

	var knob := _current if _active else center
	draw_circle(knob, 24.0, Color(0.11, 0.12, 0.16, 0.92 if _active else 0.34))
	draw_arc(knob, 24.0, 0.0, TAU, 36, Color(0.92, 0.74, 0.38, 0.94 if _active else 0.38), 2.2, true)
	draw_circle(knob, 5.5, Color(0.92, 0.74, 0.38, 0.72 if _active else 0.25))
