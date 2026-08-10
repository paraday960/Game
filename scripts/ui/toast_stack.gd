extends VBoxContainer
# اعلان‌های انباشته با اولویت و حرکت کوتاه؛ جایگزین پیام تک‌خطی قدیمی

var max_visible := 4

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation",6)
	z_index = 180

func push_message(message:String,severity:String="info"):
	while get_child_count() >= max_visible:
		get_child(0).queue_free()
	var panel=PanelContainer.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var color={"success":Color(0.18,0.88,0.59),"warning":Color(1.0,0.72,0.22),"danger":Color(1.0,0.30,0.36),"info":Color(0.25,0.78,0.94)}.get(severity,Color(0.25,0.78,0.94))
	var style=StyleBoxFlat.new();style.bg_color=Color(0.012,0.043,0.063,0.97);style.border_color=Color(color.r,color.g,color.b,0.88);style.set_border_width_all(1);style.border_width_right=5;style.set_corner_radius_all(9);style.content_margin_left=12;style.content_margin_right=12;style.content_margin_top=9;style.content_margin_bottom=9;style.shadow_color=Color(0,0,0,0.38);style.shadow_size=6;style.shadow_offset=Vector2(0,3);panel.add_theme_stylebox_override("panel",style)
	var label=Label.new();label.text=message;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",15);label.modulate=Color(0.92,0.97,0.98);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(label)
	add_child(panel)
	if not bool(SettingsManager.get_value("reduce_motion",false)):
		panel.modulate.a=0.0;panel.position.x=45.0
		var tween=create_tween().set_parallel(true);tween.tween_property(panel,"modulate:a",1.0,0.14);tween.tween_property(panel,"position:x",0.0,0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_expire(panel)

func _expire(panel:Control):
	await get_tree().create_timer(3.4).timeout
	if not is_instance_valid(panel):return
	if bool(SettingsManager.get_value("reduce_motion",false)):
		panel.queue_free();return
	var tween=create_tween().set_parallel(true);tween.tween_property(panel,"modulate:a",0.0,0.18);tween.tween_property(panel,"position:x",30.0,0.18)
	await tween.finished
	if is_instance_valid(panel):panel.queue_free()
