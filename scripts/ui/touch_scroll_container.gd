extends ScrollContainer
# اسکرول لمسی واقعی با Drag و Inertia برای Android؛ مستقل از شبیه‌سازی Mouse

var allow_vertical := true
var allow_horizontal := false
var drag_deadzone := 12.0
var _touch_id := -1
var _press_position := Vector2.ZERO
var _last_position := Vector2.ZERO
var _dragging := false
var _velocity := Vector2.ZERO

func _ready():
	set_process(true)

func _input(event):
	if not is_visible_in_tree(): return
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1 and get_global_rect().has_point(event.position) and not _point_blocked(self,event.position):
			_touch_id=event.index;_press_position=event.position;_last_position=event.position;_dragging=false;_velocity=Vector2.ZERO
		elif not event.pressed and event.index==_touch_id:
			_touch_id=-1
			if _dragging:get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==_touch_id:
		var delta=event.position-_last_position;_last_position=event.position
		if not _dragging:
			var total=event.position-_press_position
			var axis_distance=abs(total.y) if allow_vertical and not allow_horizontal else (abs(total.x) if allow_horizontal and not allow_vertical else total.length())
			var dominant=(abs(total.y)>=abs(total.x)*0.65) if allow_vertical and not allow_horizontal else ((abs(total.x)>=abs(total.y)*0.65) if allow_horizontal and not allow_vertical else true)
			if axis_distance>=drag_deadzone and dominant:_dragging=true
		if _dragging:
			_apply_delta(delta);_velocity=Vector2(-delta.x if allow_horizontal else 0.0,-delta.y if allow_vertical else 0.0)*55.0;get_viewport().set_input_as_handled()

func _process(delta:float):
	if _touch_id!=-1 or _velocity.length()<5.0:return
	if bool(SettingsManager.get_value("reduce_motion",false)):_velocity=Vector2.ZERO;return
	if allow_horizontal:scroll_horizontal=int(scroll_horizontal+_velocity.x*delta)
	if allow_vertical:scroll_vertical=int(scroll_vertical+_velocity.y*delta)
	_velocity*=exp(-7.0*delta)

func _apply_delta(delta:Vector2):
	if allow_horizontal:scroll_horizontal=int(scroll_horizontal-delta.x)
	if allow_vertical:scroll_vertical=int(scroll_vertical-delta.y)

func _point_blocked(node:Node,point:Vector2)->bool:
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree() and child.get_global_rect().has_point(point):
			if child.has_meta("block_parent_touch_scroll") and bool(child.get_meta("block_parent_touch_scroll")):return true
			if _point_blocked(child,point):return true
	return false
