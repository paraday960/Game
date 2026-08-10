extends Control
# نقشه راهبردی دوحالته: جهان و منطقه، با لایه‌های جنگ، اتحاد، تجارت، هوا، دریا و زمین

signal country_selected(code)

const WORLD_TEXTURE = preload("res://assets/maps/world_natural_earth.svg")
const PersianFont = preload("res://assets/fonts/Vazirmatn-Regular.ttf")
const LAYER_COLORS = {
	"wars":Color(1.0,0.22,0.20,0.95), "alliances":Color(0.22,0.60,1.0,0.85),
	"trade":Color(0.20,0.95,0.48,0.78), "air":Color(0.20,0.90,1.0,0.68),
	"sea":Color(0.15,0.48,1.0,0.72), "land":Color(1.0,0.68,0.18,0.70)
}

var countries:Dictionary={}
var relations:Dictionary={}
var player_country:=""
var selected_code:=""
var hovered_code:=""
var hovered_route:Dictionary={}
var world_state:Dictionary={}
var full_state:Dictionary={}
var active_layers:Dictionary={"relations":true,"wars":true,"alliances":true,"trade":true,"air":false,"sea":false,"land":false,"weather":false,"intelligence":false}
var map_mode:="global"
var allowed_countries:Array=[]
var _map_rect:=Rect2()
var _view_bounds:=Rect2(0,0,1,1)
var _drawn_routes:Array=[]

func _ready():
	custom_minimum_size=Vector2(0,500 if map_mode=="regional" else 440);mouse_filter=Control.MOUSE_FILTER_STOP;focus_mode=Control.FOCUS_ALL;resized.connect(queue_redraw);queue_redraw()

func set_map_data(new_countries:Dictionary,new_relations:Dictionary,new_player:String,new_world:Dictionary,state:Dictionary,layers:Dictionary,mode:String):
	countries=new_countries.duplicate(true);relations=new_relations.duplicate(true);player_country=new_player;world_state=new_world.duplicate(true);full_state=state;active_layers=layers.duplicate(true);map_mode=mode
	allowed_countries=MapLayerManager.get_regional_country_ids(player_country) if map_mode=="regional" else countries.keys()
	if selected_code=="" or not allowed_countries.has(selected_code):selected_code=str(allowed_countries[0]) if not allowed_countries.is_empty() else ""
	custom_minimum_size=Vector2(0,520 if map_mode=="regional" else 440);_view_bounds=_calculate_view_bounds();queue_redraw()

func set_world(new_countries:Dictionary,new_relations:Dictionary,new_player_country:String):
	set_map_data(new_countries,new_relations,new_player_country,{}, {},active_layers,"global")

func set_relations(new_relations:Dictionary):relations=new_relations.duplicate(true);queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.018,0.042,0.085),true)
	var source=Rect2(_view_bounds.position*Vector2(WORLD_TEXTURE.get_width(),WORLD_TEXTURE.get_height()),_view_bounds.size*Vector2(WORLD_TEXTURE.get_width(),WORLD_TEXTURE.get_height()))
	_map_rect=_fit_rect(source.size,size-Vector2(20,46));_map_rect.position+=Vector2(10,10)
	draw_texture_rect_region(WORLD_TEXTURE,_map_rect,source,Color(0.58,0.72,0.82,0.72));draw_rect(_map_rect,Color(0.25,0.55,0.75,0.8),false,2.0)
	_drawn_routes.clear();_draw_routes();_draw_hubs_and_chokepoints();_draw_countries();_draw_legend()
	if not hovered_route.is_empty():_draw_route_tooltip()

func _draw_routes():
	for layer in ["trade","alliances","wars","land","air","sea"]:
		if not active_layers.get(layer,false):continue
		var route_list=MapLayerManager.get_dynamic_routes(full_state,layer,allowed_countries)
		if layer in ["air","sea"]:route_list.append_array(MapLayerManager.get_static_routes(layer,allowed_countries))
		for route in route_list:
			var a=_geo_point(float(route.get("from_lon",0)),float(route.get("from_lat",0)));var b=_geo_point(float(route.get("to_lon",0)),float(route.get("to_lat",0)))
			if not _map_rect.has_point(a) or not _map_rect.has_point(b):continue
			var points=_curve_points(a,b,layer);var color:Color=LAYER_COLORS.get(layer,Color.WHITE);var width=1.2+float(route.get("volume",0.5))*2.2
			if layer=="wars":_draw_dashed(points,color,width)
			else:draw_polyline(points,color,width,true)
			var record=route.duplicate(true);record["points"]=points;record["color"]=color;_drawn_routes.append(record)

func _draw_hubs_and_chokepoints():
	for layer in ["air","sea"]:
		if not active_layers.get(layer,false):continue
		for hub in MapLayerManager.get_hubs(layer,allowed_countries):
			var p=_geo_point(float(hub.get("lon",0)),float(hub.get("lat",0)))
			if not _map_rect.has_point(p):continue
			var color=LAYER_COLORS[layer];draw_circle(p,3.0+float(hub.get("capacity",0.5))*3.0,Color(0.02,0.04,0.08,0.9));draw_circle(p,2.0+float(hub.get("capacity",0.5))*2.0,color)
			if map_mode=="regional":draw_string(PersianFont,p+Vector2(8,4),str(hub.get("name_fa","")),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.86,0.92,1.0))
	if active_layers.get("sea",false):
		for choke in MapLayerManager.get_chokepoints():
			var p=_geo_point(float(choke.get("lon",0)),float(choke.get("lat",0)))
			if _map_rect.has_point(p):draw_rect(Rect2(p-Vector2(4,4),Vector2(8,8)),Color(1.0,0.82,0.20),true);draw_string(PersianFont,p+Vector2(7,-5),str(choke.get("name_fa","")),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(1.0,0.9,0.5))

func _draw_countries():
	for code in allowed_countries:
		if code==player_country or not countries.has(code):continue
		var point=_country_point(code);if not _map_rect.has_point(point):continue
		var relation=float(relations.get(code,50.0));var color=_relation_color(relation) if active_layers.get("relations",true) else Color(0.62,0.68,0.74)
		var radius=(3.0 if map_mode=="global" else 5.0)+float(countries[code].get("strategic_weight",0.3))*3.0
		if code==hovered_code:radius+=4.0
		if code==selected_code:draw_circle(point,radius+7.0,Color(1.0,0.86,0.3,0.32))
		if active_layers.get("wars",false) and countries[code].get("at_war",false):draw_arc(point,radius+5,0,TAU,20,LAYER_COLORS["wars"],2.5)
		if active_layers.get("weather",false):
			var heat=float(countries[code].get("heat_factor",0.5));var snow=float(countries[code].get("snow_factor",0.2));draw_arc(point,radius+3,0,TAU,18,Color(1.0,0.35+snow*.5,0.15+heat*.3,0.75),1.4)
		if active_layers.get("intelligence",false) and _has_intelligence_report(code):draw_arc(point,radius+7,0,TAU,22,Color(0.85,0.35,1.0),2.0)
		draw_circle(point,radius+2,Color(0.02,0.05,0.10,0.92));draw_circle(point,radius,color)
		if code==hovered_code or code==selected_code or map_mode=="regional":_draw_country_label(code,point,relation)
	if countries.has(player_country):
		var home=_country_point(player_country);draw_circle(home,13.0,Color(0.15,0.65,1.0));draw_arc(home,17.0,0,TAU,32,Color.WHITE,2.5);draw_string(PersianFont,home+Vector2(20,5),"کشور شما: "+_country_name(player_country),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.72,0.9,1.0))

func _draw_country_label(code:String,point:Vector2,relation:float):
	var label="%s  رابطه %s"%[_country_name(code),_persian_number(int(relation))];var width=min(260.0,80.0+label.length()*6.0);var pos=point+Vector2(13,-16)
	if pos.x+width>_map_rect.end.x:pos.x=point.x-width-13
	draw_rect(Rect2(pos-Vector2(4,15),Vector2(width,22)),Color(0.02,0.05,0.10,0.82),true);draw_string(PersianFont,pos,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)

func _draw_legend():
	var x=12.0;var y=size.y-17.0
	for layer in ["wars","alliances","trade","air","sea","land"]:
		if not active_layers.get(layer,false):continue
		draw_line(Vector2(x,y-4),Vector2(x+18,y-4),LAYER_COLORS[layer],3);draw_string(PersianFont,Vector2(x+22,y),_layer_name(layer),HORIZONTAL_ALIGNMENT_LEFT,80,12,Color.WHITE);x+=105

func _draw_route_tooltip():
	var label=str(hovered_route.get("label",_layer_name(str(hovered_route.get("type","")))));var p=get_local_mouse_position()+Vector2(12,-12);var w=min(340.0,90.0+label.length()*7.0)
	if p.x+w>size.x:p.x-=w+24
	draw_rect(Rect2(p-Vector2(5,18),Vector2(w,28)),Color(0.01,0.03,0.07,0.94),true);draw_string(PersianFont,p,label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)

func _gui_input(event):
	if event is InputEventMouseMotion:
		var next=_nearest_country(event.position);var route=_nearest_route(event.position)
		if next!=hovered_code or route!=hovered_route:hovered_code=next;hovered_route=route;mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if next!="" or not route.is_empty() else Control.CURSOR_ARROW;queue_redraw()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var code=_nearest_country(event.position)
		if code!="":selected_code=code;queue_redraw();emit_signal("country_selected",code)
	elif event is InputEventKey and event.pressed and event.is_action("ui_accept"):
		var codes=allowed_countries;if codes.is_empty():return
		selected_code=str(codes[0]) if selected_code=="" else str(codes[(codes.find(selected_code)+1)%codes.size()]);queue_redraw();emit_signal("country_selected",selected_code)

func _nearest_country(position:Vector2)->String:
	var best="";var best_distance=18.0
	for code in allowed_countries:
		if code==player_country or not countries.has(code):continue
		var distance=position.distance_to(_country_point(code))
		if distance<best_distance:best_distance=distance;best=str(code)
	return best

func _nearest_route(position:Vector2)->Dictionary:
	var best:Dictionary={};var best_distance=9.0
	for route in _drawn_routes:
		var points:PackedVector2Array=route.get("points",PackedVector2Array())
		for i in range(points.size()-1):
			var d=Geometry2D.get_closest_point_to_segment(position,points[i],points[i+1]).distance_to(position)
			if d<best_distance:best_distance=d;best=route
	return best

func _curve_points(a:Vector2,b:Vector2,layer:String)->PackedVector2Array:
	var points:=PackedVector2Array();var mid=(a+b)*0.5;var delta=b-a;var normal=Vector2(-delta.y,delta.x).normalized();var bend=min(70.0,delta.length()*0.18)*(1.0 if layer in ["air","alliances"] else 0.45);var control=mid+normal*bend
	for i in range(25):
		var t=float(i)/24.0;points.append((1-t)*(1-t)*a+2*(1-t)*t*control+t*t*b)
	return points

func _draw_dashed(points:PackedVector2Array,color:Color,width:float):
	for i in range(points.size()-1):
		if i%2==0:draw_line(points[i],points[i+1],color,width,true)

func _calculate_view_bounds()->Rect2:
	if map_mode!="regional" or allowed_countries.is_empty():return Rect2(0,0,1,1)
	var minp=Vector2(1,1);var maxp=Vector2(0,0)
	for code in allowed_countries:
		var c=countries.get(code,WorldManager.get_country(str(code)));var p=_geo_normalized(float(c.get("lon",0)),float(c.get("lat",0)));minp.x=min(minp.x,p.x);minp.y=min(minp.y,p.y);maxp.x=max(maxp.x,p.x);maxp.y=max(maxp.y,p.y)
	if maxp.x-minp.x>0.72:return Rect2(0,0,1,1)
	var padding=Vector2(0.07,0.10);minp=(minp-padding).clamp(Vector2.ZERO,Vector2.ONE);maxp=(maxp+padding).clamp(Vector2.ZERO,Vector2.ONE)
	return Rect2(minp,Vector2(max(0.20,maxp.x-minp.x),max(0.20,maxp.y-minp.y)))

func _country_point(code:String)->Vector2:
	var c=countries.get(code,{});return _geo_point(float(c.get("lon",0)),float(c.get("lat",0)))
func _geo_point(lon:float,lat:float)->Vector2:
	var n=_geo_normalized(lon,lat);return _map_rect.position+Vector2((n.x-_view_bounds.position.x)/_view_bounds.size.x,(n.y-_view_bounds.position.y)/_view_bounds.size.y)*_map_rect.size
func _geo_normalized(lon:float,lat:float)->Vector2:
	lon=clamp(lon,-180.0,180.0);lat=clamp(lat,-80.0,80.0);var m=log(tan(PI/4.0+deg_to_rad(lat)/2.0));return Vector2((lon+180.0)/360.0,clamp(0.5-m/(2.0*PI),0.02,0.98))
func _fit_rect(texture_size:Vector2,available:Vector2)->Rect2:
	var scale=min(available.x/texture_size.x,available.y/texture_size.y);var fitted=texture_size*scale;return Rect2((available-fitted)*0.5,fitted)
func _relation_color(value:float)->Color:
	var n=clamp(value/100.0,0,1);return Color(0.25,0.9,0.45) if n>=0.65 else (Color(1.0,0.78,0.22) if n>=0.40 else Color(1.0,0.3,0.32))
func _country_name(code:String)->String:return str(countries.get(code,{}).get("name_fa",code))
func _has_intelligence_report(code:String)->bool:
	for report in full_state.get("intelligence_operations",{}).get("reports",[]):
		if report.get("target","")==code:return true
	return false
func _layer_name(layer:String)->String:return {"wars":"جنگ","alliances":"اتحاد","trade":"تجارت","air":"هوایی","sea":"دریایی","land":"زمینی"}.get(layer,layer)
func _persian_number(value:int)->String:
	var result=str(value);var en="0123456789";var fa="۰۱۲۳۴۵۶۷۸۹"
	for i in range(en.length()):result=result.replace(en[i],fa[i])
	return result
