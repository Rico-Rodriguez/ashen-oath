class_name VirtualThumbstick
extends Control

signal move_vector_changed(vec: Vector2)

const MAX_RADIUS: float = 92.0
const DEADZONE_PX: float = 10.0

@export var floating: bool = true

var is_right_side: bool = false
var safe_bottom: float = 0.0

var _active: bool = false
var _seen_touch: bool = false
var _touch_index: int = -1
var _origin: Vector2 = Vector2.ZERO
var _current: Vector2 = Vector2.ZERO
var _output: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _active:
			reset_stick()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if _active and not is_visible_in_tree():
			reset_stick()


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


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.index == _touch_index and (not st.pressed or st.canceled):
			reset_stick()
	elif event is InputEventMouseButton and not _seen_touch:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _touch_index == -99:
			reset_stick()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_seen_touch = true
		var st := event as InputEventScreenTouch
		if st.canceled:
			if _active and st.index == _touch_index:
				reset_stick()
				accept_event()
			return
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
		_seen_touch = true
		var sd := event as InputEventScreenDrag
		if _active and sd.index == _touch_index:
			_current = sd.position
			_update_output()
			accept_event()
	elif event is InputEventMouseButton:
		if _seen_touch:
			return
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
		if _seen_touch:
			return
		var mm := event as InputEventMouseMotion
		if _active and _touch_index == -99:
			_current = mm.position
			_update_output()
			accept_event()


func _update_output() -> void:
	var delta := _current - _origin
	var dist := delta.length()
	if dist > MAX_RADIUS:
		var dir := delta / dist
		if floating:
			var pad := MAX_RADIUS
			var min_x := minf(pad, size.x * 0.5)
			var max_x := maxf(min_x, size.x - pad)
			var min_y := minf(pad, size.y * 0.5)
			var max_y := maxf(min_y, size.y - pad - safe_bottom)
			var shifted := _current - dir * MAX_RADIUS
			_origin = Vector2(
				clampf(shifted.x, min_x, max_x),
				clampf(shifted.y, min_y, max_y)
			)
			delta = _current - _origin
			dist = delta.length()
		if dist > MAX_RADIUS:
			delta = (delta / dist) * MAX_RADIUS
			_current = _origin + delta
			dist = MAX_RADIUS

	if dist < DEADZONE_PX:
		_output = Vector2.ZERO
	else:
		var t := clampf((dist - DEADZONE_PX) / (MAX_RADIUS - DEADZONE_PX), 0.0, 1.0)
		_output = (delta / dist) * t
	move_vector_changed.emit(_output)
	queue_redraw()


func _draw() -> void:
	if not _active:
		return

	var center := _origin
	draw_circle(center, MAX_RADIUS, Color(0.045, 0.052, 0.072, 0.30))
	draw_arc(center, MAX_RADIUS, 0.0, TAU, 56, Color(0.82, 0.65, 0.34, 0.78), 2.5, true)
	draw_arc(center, MAX_RADIUS * 0.58, 0.0, TAU, 40, Color(0.64, 0.50, 0.26, 0.38), 1.4, true)

	var tick_col := Color(0.86, 0.70, 0.38, 0.50)
	for i in range(4):
		var a := float(i) * (PI * 0.5)
		var dir := Vector2(cos(a), sin(a))
		draw_line(center + dir * (MAX_RADIUS - 9.0), center + dir * (MAX_RADIUS - 1.5), tick_col, 1.8, true)

	var out_mag := _output.length()
	if out_mag > 0.05:
		var steer_ang := atan2(_output.y, _output.x)
		var wedge_half := 0.34
		var wedge_alpha := clampf(0.28 + out_mag * 0.44, 0.28, 0.72)
		var wedge_pts := PackedVector2Array([center])
		var steps := 10
		for i in range(steps + 1):
			var wa := lerpf(steer_ang - wedge_half, steer_ang + wedge_half, float(i) / float(steps))
			wedge_pts.append(center + Vector2(cos(wa), sin(wa)) * (MAX_RADIUS - 2.0))
		draw_colored_polygon(wedge_pts, Color(0.92, 0.74, 0.36, wedge_alpha * 0.38))
		draw_arc(center, MAX_RADIUS - 1.5, steer_ang - wedge_half, steer_ang + wedge_half, 16, Color(1.0, 0.84, 0.46, wedge_alpha + 0.18), 3.6, true)

	var knob := _current
	draw_circle(knob, 26.0, Color(0.11, 0.12, 0.16, 0.92))
	draw_arc(knob, 26.0, 0.0, TAU, 36, Color(0.95, 0.77, 0.40, 0.96), 2.4, true)
	draw_circle(knob, 6.0, Color(0.96, 0.80, 0.44, 0.82))
