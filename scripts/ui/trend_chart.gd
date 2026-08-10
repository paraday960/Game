extends Control
# نمودار تعاملی روند ماهانه: Hover/Touch، Crosshair و مقدار دقیق هر سری

const PersianFont = preload("res://assets/fonts/Vazirmatn-Regular.ttf")
const SERIES = [
	{"key":"happiness", "name":"شادی", "color":Color(0.30, 0.95, 0.52)},
	{"key":"stability", "name":"ثبات", "color":Color(0.30, 0.70, 1.00)},
	{"key":"power", "name":"قدرت", "color":Color(1.00, 0.72, 0.24)},
	{"key":"gdp_index", "name":"رشد اقتصاد", "color":Color(0.82, 0.45, 1.00)}
]

var history: Array = []
var hovered_index := -1
var _plot := Rect2()

func _ready():
	custom_minimum_size = Vector2(0, 330)
	mouse_filter=Control.MOUSE_FILTER_STOP
	focus_mode=Control.FOCUS_ALL
	resized.connect(queue_redraw)

func set_history(value: Array):
	history = value.duplicate(true)
	hovered_index=history.size()-1 if not history.is_empty() else -1
	queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.038, 0.065), true)
	for i in range(12):
		var ratio=float(i)/11.0;draw_rect(Rect2(0,size.y*ratio,size.x,size.y/11.0+1),Color(0.03,0.12,0.16,0.045*(1.0-ratio)),true)
	_plot = Rect2(Vector2(58, 45), Vector2(max(10.0, size.x - 88), max(10.0, size.y - 112)))
	for i in range(5):
		var y = _plot.position.y + _plot.size.y * float(i) / 4.0
		draw_line(Vector2(_plot.position.x, y), Vector2(_plot.end.x, y), Color(0.35, 0.62, 0.70, 0.18), 1.0)
		draw_string(PersianFont, Vector2(8, y + 5), "%s٪" % _fa(str(100-i*25)), HORIZONTAL_ALIGNMENT_LEFT, 45, 12, Color(0.57,0.70,0.77))
	draw_rect(_plot,Color(0.25,0.68,0.75,0.58),false,1.2)
	if history.size()<2:
		draw_string(PersianFont,_plot.get_center()+Vector2(-145,4),"نمودار پس از نخستین ماه شکل می‌گیرد",HORIZONTAL_ALIGNMENT_CENTER,290,16,Color(0.76,0.84,0.88));_draw_legend();return
	for definition in SERIES:
		var points:=PackedVector2Array()
		for i in range(history.size()):
			var x=_plot.position.x+_plot.size.x*float(i)/float(history.size()-1)
			var normalized=_normalized_value(str(definition.key),history[i].get(definition.key,0.0));points.append(Vector2(x,_plot.end.y-normalized*_plot.size.y))
		if points.size()>=2:
			var area=points.duplicate();area.append(Vector2(points[-1].x,_plot.end.y));area.append(Vector2(points[0].x,_plot.end.y));var fill:Color=definition.color;fill.a=0.055;draw_colored_polygon(area,fill)
			draw_polyline(points,definition.color,2.5,true)
			if hovered_index>=0 and hovered_index<points.size():draw_circle(points[hovered_index],4.5,Color(0.01,0.03,0.05));draw_circle(points[hovered_index],3.0,definition.color)
	if hovered_index>=0 and hovered_index<history.size():
		var x=_plot.position.x+_plot.size.x*float(hovered_index)/float(history.size()-1);draw_line(Vector2(x,_plot.position.y),Vector2(x,_plot.end.y),Color(1,1,1,0.38),1.0);_draw_hover_card(x)
	_draw_axis_dates();_draw_legend()

func _draw_hover_card(x:float):
	var record:Dictionary=history[hovered_index];var width=270.0;var pos=Vector2(clamp(x-width*0.5,_plot.position.x,_plot.end.x-width),6)
	draw_rect(Rect2(pos,Vector2(width,31)),Color(0.005,0.021,0.034,0.96),true);draw_rect(Rect2(pos,Vector2(width,31)),Color(0.28,0.78,0.82,0.65),false,1.0)
	var title=str(record.get("label",record.get("month_name","ماه %s"%_fa(str(hovered_index+1)))))
	var values=[]
	for definition in SERIES:values.append("%s %s٪"%[definition.name,_fa(str(int(_normalized_value(str(definition.key),record.get(definition.key,0))*100)))])
	draw_string(PersianFont,pos+Vector2(8,21),title+" · "+" | ".join(values),HORIZONTAL_ALIGNMENT_LEFT,width-16,11,Color(0.94,0.98,1.0))

func _draw_axis_dates():
	if history.is_empty():return
	var first=str(history[0].get("label","شروع"));var last=str(history[-1].get("label","اکنون"))
	draw_string(PersianFont,Vector2(_plot.position.x,_plot.end.y+20),first,HORIZONTAL_ALIGNMENT_LEFT,120,11,Color(0.53,0.66,0.73))
	draw_string(PersianFont,Vector2(_plot.end.x-120,_plot.end.y+20),last,HORIZONTAL_ALIGNMENT_RIGHT,120,11,Color(0.53,0.66,0.73))

func _draw_legend():
	var legend_x=_plot.position.x
	for definition in SERIES:
		draw_circle(Vector2(legend_x+6,size.y-22),5.0,definition.color);draw_string(PersianFont,Vector2(legend_x+16,size.y-16),str(definition.name),HORIZONTAL_ALIGNMENT_LEFT,105,13,Color.WHITE);legend_x+=125

func _gui_input(event):
	if history.size()<2:return
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_update_hover(event.position);grab_focus()
	elif event is InputEventKey and event.pressed:
		if event.keycode==KEY_LEFT:hovered_index=max(0,hovered_index-1);queue_redraw()
		elif event.keycode==KEY_RIGHT:hovered_index=min(history.size()-1,hovered_index+1);queue_redraw()

func _update_hover(position:Vector2):
	if not _plot.grow(10).has_point(position):return
	var ratio=clamp((position.x-_plot.position.x)/max(1.0,_plot.size.x),0.0,1.0);var index=int(round(ratio*float(history.size()-1)))
	if index!=hovered_index:hovered_index=index;queue_redraw()

func _normalized_value(key:String,raw)->float:
	var value=float(raw)
	if key=="gdp_index":return clamp((value-0.80)/0.50,0.0,1.0)
	return clamp(value,0.0,1.0)

func _fa(text:String)->String:
	var result=text;var en="0123456789";var fa="۰۱۲۳۴۵۶۷۸۹"
	for i in range(10):result=result.replace(en[i],fa[i])
	return result
