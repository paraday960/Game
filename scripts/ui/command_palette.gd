extends Control
# جست‌وجوی فرمان، کشور و سامانه؛ مسیر سریع برای بازیکن حرفه‌ای و موبایل

signal item_chosen(kind, id)
signal closed

const PersianFont = preload("res://assets/fonts/Vazirmatn-Regular.ttf")
const TouchScrollClass = preload("res://scripts/ui/touch_scroll_container.gd")
var entries: Array = []
var search_edit: LineEdit
var results_box: VBoxContainer
var panel: PanelContainer
var empty_label: Label

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	_build()
	hide()

func set_entries(value: Array):
	entries = value.duplicate(true)
	if is_instance_valid(search_edit):
		_refresh_results("")

func open_palette(initial_query: String = ""):
	show()
	search_edit.text = initial_query
	_refresh_results(initial_query)
	search_edit.grab_focus()
	search_edit.caret_column = search_edit.text.length()
	if not bool(SettingsManager.get_value("reduce_motion", false)):
		panel.modulate.a = 0.0
		panel.scale = Vector2(0.97,0.97)
		panel.pivot_offset = panel.size * 0.5
		var tween = create_tween().set_parallel(true)
		tween.tween_property(panel,"modulate:a",1.0,0.14)
		tween.tween_property(panel,"scale",Vector2.ONE,0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func close_palette():
	if not visible: return
	hide()
	emit_signal("closed")

func _build():
	var dim = ColorRect.new(); dim.set_anchors_preset(Control.PRESET_FULL_RECT); dim.color = Color(0.0,0.01,0.02,0.78); dim.mouse_filter = Control.MOUSE_FILTER_STOP; dim.gui_input.connect(_on_dim_input); add_child(dim)
	panel = PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.anchor_left=0.08;panel.anchor_right=0.92;panel.anchor_top=0.10;panel.anchor_bottom=0.82;panel.offset_left=0;panel.offset_right=0;panel.offset_top=0;panel.offset_bottom=0; panel.theme_type_variation="CommandPanel"; add_child(panel)
	var box = VBoxContainer.new(); box.add_theme_constant_override("separation",10); panel.add_child(box)
	var header = HBoxContainer.new(); box.add_child(header)
	var title = Label.new(); title.text="فرمان سریع"; title.add_theme_font_size_override("font_size",34); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(title)
	var shortcut = Label.new(); shortcut.text="Ctrl + K"; shortcut.modulate=Color(0.52,0.68,0.75); header.add_child(shortcut)
	var close = Button.new(); close.text="بستن"; close.custom_minimum_size=Vector2(125,62);close.add_theme_font_size_override("font_size",24); close.pressed.connect(close_palette); header.add_child(close)
	search_edit = LineEdit.new(); search_edit.placeholder_text="جست‌وجوی کشور، سامانه یا بخش مدیریتی…"; search_edit.custom_minimum_size=Vector2(0,72); search_edit.add_theme_font_size_override("font_size",28); search_edit.text_changed.connect(_refresh_results); search_edit.text_submitted.connect(_on_submit); box.add_child(search_edit)
	var help = Label.new(); help.text="نام را بنویسید؛ نخستین نتیجه با Enter اجرا می‌شود."; help.modulate=Color(0.57,0.72,0.79); help.add_theme_font_size_override("font_size",20); box.add_child(help)
	var scroll = TouchScrollClass.new();scroll.allow_vertical=true;scroll.allow_horizontal=false; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; box.add_child(scroll)
	results_box = VBoxContainer.new(); results_box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; results_box.add_theme_constant_override("separation",5); scroll.add_child(results_box)
	empty_label = Label.new(); empty_label.text="نتیجه‌ای پیدا نشد"; empty_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; empty_label.modulate=Color(0.75,0.55,0.52); empty_label.hide(); box.add_child(empty_label)

func _refresh_results(query: String):
	for child in results_box.get_children(): child.queue_free()
	var normalized = query.strip_edges().to_lower()
	var matches: Array = []
	for entry in entries:
		var haystack = (str(entry.get("title",""))+" "+str(entry.get("keywords",""))).to_lower()
		if normalized == "" or haystack.contains(normalized): matches.append(entry)
	matches.sort_custom(func(a,b):
		var aq = 0 if str(a.get("title","")).to_lower().begins_with(normalized) else 1
		var bq = 0 if str(b.get("title","")).to_lower().begins_with(normalized) else 1
		return aq < bq if aq != bq else str(a.get("title","")) < str(b.get("title","")))
	var shown = min(14,matches.size())
	for index in range(shown):
		var entry:Dictionary=matches[index]
		var button=Button.new(); button.text="%s  ·  %s"%[entry.get("group","فرمان"),entry.get("title","")];button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size=Vector2(0,68);button.add_theme_font_size_override("font_size",25);button.tooltip_text=str(entry.get("description","")) if bool(SettingsManager.get_value("tooltips_enabled",true)) else "";button.pressed.connect(_choose.bind(str(entry.get("kind","")),str(entry.get("id",""))));results_box.add_child(button)
	empty_label.visible = shown == 0

func _on_submit(_text:String):
	for child in results_box.get_children():
		if child is Button and not child.is_queued_for_deletion():
			child.emit_signal("pressed");return

func _choose(kind:String,id:String):
	FeedbackManager.play_click()
	hide()
	emit_signal("item_chosen",kind,id)

func _on_dim_input(event):
	if event is InputEventMouseButton and event.pressed: close_palette()
	elif event is InputEventScreenTouch and event.pressed: close_palette()

func _input(event):
	if visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		close_palette();get_viewport().set_input_as_handled()
