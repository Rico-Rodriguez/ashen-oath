class_name VirtualThumbstick
extends Control

signal move_vector_changed(vec: Vector2)

const MAX_RADIUS: float = 64.0
const DEADZONE: float = 0.10

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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and not _active:
			_active = true
			_touch_index = st.index
			_origin = st.position
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
				_origin = mb.position
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
	var norm := delta / MAX_RADIUS
	if norm.length() < DEADZONE:
		norm = Vector2.ZERO
	_output = norm
	move_vector_changed.emit(_output)
	queue_redraw()


func _draw() -> void:
	var center := _origin if _active else Vector2(118.0, size.y - 118.0)
	if not _active and position.x > 200.0:
		center = Vector2(size.x - 118.0, size.y - 118.0)

	var ring_alpha := 0.78 if _active else 0.24
	var fill_alpha := 0.36 if _active else 0.10
	draw_circle(center, MAX_RADIUS, Color(0.05, 0.06, 0.08, fill_alpha))
	draw_arc(center, MAX_RADIUS, 0.0, TAU, 48, Color(0.78, 0.62, 0.33, ring_alpha), 2.5, true)
	draw_arc(center, MAX_RADIUS * 0.62, 0.0, TAU, 36, Color(0.55, 0.45, 0.25, ring_alpha * 0.45), 1.2, true)

	var knob := _current if _active else center
	draw_circle(knob, 24.0, Color(0.14, 0.15, 0.19, 0.90 if _active else 0.32))
	draw_arc(knob, 24.0, 0.0, TAU, 32, Color(0.92, 0.74, 0.38, 0.95 if _active else 0.35), 2.2, true)
