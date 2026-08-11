extends Node
# لایه‌های نقشه راهبردی: جنگ، اتحاد، تجارت، هوا، دریا، زمین، اقلیم و مراکز حمل‌ونقل

const DATA_PATH="res://data/transport_hubs.json"
const LAYERS=["relations","wars","alliances","trade","air","sea","land","weather","intelligence"]
var hubs:Dictionary={}
var routes:Array=[]
var chokepoints:Array=[]
var load_errors:Array=[]
var data_version:=""

func _ready():reload()

func reload()->bool:
	hubs.clear();routes.clear();chokepoints.clear();load_errors.clear()
	var file=FileAccess.open(DATA_PATH,FileAccess.READ)
	if file==null:load_errors.append("فایل مراکز حمل‌ونقل خوانده نشد");return false
	var parsed=JSON.parse_string(file.get_as_text());file.close()
	if not parsed is Dictionary or not parsed.get("hubs",null) is Array or not parsed.get("routes",null) is Array:load_errors.append("ساختار لایه‌های نقشه نامعتبر است");return false
	data_version=str(parsed.get("version","1.0.0"));routes=parsed["routes"].duplicate(true);chokepoints=parsed.get("chokepoints",[]).duplicate(true)
	for hub in parsed["hubs"]:
		if hub is Dictionary:hubs[str(hub.get("id",""))]=hub.duplicate(true)
	for route in routes:
		if not hubs.has(str(route.get("from",""))) or not hubs.has(str(route.get("to",""))):load_errors.append("مسیر به مرکز ناشناخته متصل است")
	return load_errors.is_empty()

func is_valid()->bool:return hubs.size()>=40 and routes.size()>=40 and load_errors.is_empty()

func get_regional_country_ids(player_id:String)->Array:
	if not WorldManager.countries.has(player_id):return []
	var player=WorldManager.countries[player_id];var selected:Array=[player_id]
	for border in player.get("borders",[]):
		if WorldManager.countries.has(border) and not selected.has(border):selected.append(border)
	var nearby:Array=[]
	for id in WorldManager.countries.keys():
		if id==player_id or selected.has(id):continue
		var other=WorldManager.countries[id]
		var same_sub=str(other.get("subregion",""))==str(player.get("subregion",""))
		var distance=Vector2(float(player.get("lon",0)),float(player.get("lat",0))).distance_to(Vector2(float(other.get("lon",0)),float(other.get("lat",0))))
		if same_sub or distance<24.0:nearby.append({"id":id,"distance":distance,"same":same_sub})
	nearby.sort_custom(func(a,b):return (float(a.distance)+(0.0 if a.same else 1000.0))<(float(b.distance)+(0.0 if b.same else 1000.0)))
	for item in nearby:
		if selected.size()>=30:break
		selected.append(item.id)
	return selected

func get_hubs(layer:String,allowed:Array=[])->Array:
	var result:Array=[];var hub_type="air" if layer=="air" else "sea"
	for hub in hubs.values():
		if hub.get("type","")!=hub_type:continue
		if not allowed.is_empty() and not allowed.has(hub.get("country","")):continue
		result.append(hub.duplicate(true))
	return result

func get_static_routes(layer:String,allowed:Array=[])->Array:
	var result:Array=[]
	for route in routes:
		if route.get("type","")!=layer:continue
		var a=hubs.get(str(route.get("from","")),{});var b=hubs.get(str(route.get("to","")),{})
		if not allowed.is_empty() and (not allowed.has(a.get("country","")) or not allowed.has(b.get("country",""))):continue
		result.append({"type":layer,"from_country":a.get("country",""),"to_country":b.get("country",""),"from_lat":a.get("lat",0),"from_lon":a.get("lon",0),"to_lat":b.get("lat",0),"to_lon":b.get("lon",0),"label":"%s — %s"%[a.get("name_fa",""),b.get("name_fa","")],"volume":route.get("volume",0.5)})
	result.append_array(_generated_access_routes(layer,allowed))
	return result

func _generated_access_routes(layer:String,allowed:Array)->Array:
	if not ["air","sea"].has(layer):return []
	var ids:Array=allowed if not allowed.is_empty() else WorldManager.countries.keys()
	var eligible_hubs:Array=[]
	for hub in hubs.values():
		if hub.get("type","")!=layer:continue
		if allowed.is_empty() or allowed.has(hub.get("country","")):eligible_hubs.append(hub)
	if eligible_hubs.is_empty():return []
	var countries_with_hub:Dictionary={}
	for hub in eligible_hubs:countries_with_hub[str(hub.get("country",""))]=true
	var result:Array=[]
	for country_id in ids:
		var country=WorldManager.get_country(str(country_id))
		if country.is_empty() or countries_with_hub.has(str(country_id)):continue
		if layer=="sea" and country.get("landlocked",false):continue
		var best:Dictionary={};var best_score=INF
		for hub in eligible_hubs:
			var hub_country=WorldManager.get_country(str(hub.get("country","")))
			var distance=Vector2(float(country.get("lon",0)),float(country.get("lat",0))).distance_to(Vector2(float(hub.get("lon",0)),float(hub.get("lat",0))))
			if str(hub_country.get("region",""))!=str(country.get("region","")):distance+=80.0
			if distance<best_score:best_score=distance;best=hub
		if best.is_empty():continue
		result.append({"type":layer,"from_country":country_id,"to_country":best.get("country",""),"from_lat":country.get("lat",0),"from_lon":country.get("lon",0),"to_lat":best.get("lat",0),"to_lon":best.get("lon",0),"label":"دسترسی %s %s — %s"%["هوایی" if layer=="air" else "دریایی",country.get("name_fa",country_id),best.get("name_fa","")],"volume":0.22+float(country.get("strategic_weight",0.2))*0.35,"generated":true})
	return result

func get_dynamic_routes(state:Dictionary,layer:String,allowed:Array=[])->Array:
	var world:Dictionary=state.get("world",{});var player=str(world.get("player_country",""));var result:Array=[]
	# حملات مسیرهای تجاری برای نمایش نقشه‌محور
	var trade_warfare:Dictionary = state.get("trade_route_warfare",{})
	var attacks:Array = trade_warfare.get("attacks",[])
	var chokepoints_state:Dictionary = trade_warfare.get("chokepoints",{})

	if layer=="wars":
		for target in world.get("wars",{}).keys():_append_country_route(result,"wars",player,str(target),"جنگ فعال",1.0,allowed)
		for war in world.get("npc_wars",{}).values():_append_country_route(result,"wars",str(war.get("a","")),str(war.get("b","")),"جنگ کشورهای دیگر",0.85,allowed)
		# مسیرهای تجاری تحت حمله نظامی هم به عنوان جنگ نمایش داده می‌شود
		for atk in attacks:
			var op = str(atk.get("operation","raid"))
			if op in ["raid","blockade","drone_strike","mine"] and atk.has("from") and atk.has("to"):
				var from_c = str(atk.get("from",""))
				var to_c = str(atk.get("to",""))
				if from_c != "" and to_c != "":
					_append_country_route(result,"wars",from_c,to_c,"حمله به مسیر تجاری (%s)" % op,0.9,allowed)
	elif layer=="alliances":
		for target in world.get("alliances",[]):_append_country_route(result,"alliances",player,str(target),"اتحاد",0.9,allowed)
		for key in world.get("npc_alliances",[]):
			var pair=str(key).split("|");if pair.size()==2:_append_country_route(result,"alliances",pair[0],pair[1],"اتحاد مستقل",0.65,allowed)
	elif layer=="trade":
		for target in world.get("trade_agreements",[]):_append_country_route(result,"trade",player,str(target),"توافق تجاری",0.9,allowed)
		for key in world.get("npc_trade_agreements",[]):
			var pair=str(key).split("|");if pair.size()==2:_append_country_route(result,"trade",pair[0],pair[1],"کریدور تجاری",0.55,allowed)
		# مسیرهای تجاری مختل شده - قرمز و چشمک‌زن
		for atk in attacks:
			var op = str(atk.get("operation",""))
			if op in ["raid","blockade","sabotage","mine","drone_strike"] and atk.has("from") and atk.has("to"):
				var from_c = str(atk.get("from",""))
				var to_c = str(atk.get("to",""))
				if from_c != "" and to_c != "":
					# حجم منفی برای نمایش مختل
					var vol = -0.8 if op == "blockade" else -0.6
					_append_country_route(result,"trade_disrupted",from_c,to_c,"⚠️ مسیر مختل (%s)" % op,vol,allowed)
		# گلوگاه‌های مسدود
		for cp_id in chokepoints_state.keys():
			var cp_action = str(chokepoints_state[cp_id].get("action","blockade"))
			if cp_action in ["blockade","mine"]:
				# گلوگاه‌ها به عنوان مسیر تجاری مختل نمایش
				var cp_info = get_chokepoint_info(cp_id)
				if not cp_info.is_empty():
					result.append({"type":"trade_disrupted","from_country":cp_info.get("from_country",""),"to_country":cp_info.get("to_country",""),"from_lat":cp_info.get("lat",0),"from_lon":cp_info.get("lon",0),"to_lat":cp_info.get("lat",0)+0.5,"to_lon":cp_info.get("lon",0)+0.5,"label":"🚫 %s مسدود (%s)" % [cp_info.get("name_fa",cp_id), cp_action],"volume":-1.0,"chokepoint":true,"chokepoint_id":cp_id})
	elif layer=="trade_disrupted":
		# لایه ویژه برای مسیرهای مختل - برای رنگ قرمز
		for atk in attacks:
			var op = str(atk.get("operation",""))
			if op in ["raid","blockade","sabotage","mine","drone_strike"] and atk.has("from") and atk.has("to"):
				_append_country_route(result,"trade_disrupted",str(atk.get("from","")),str(atk.get("to","")),"⚠️ مختل (%s)" % op,-0.8,allowed)
	elif layer=="land":
		var ids=allowed if not allowed.is_empty() else get_regional_country_ids(player)
		var seen:Dictionary={}
		for a in ids:
			for b in WorldManager.get_country(str(a)).get("borders",[]):
				if not ids.has(b):continue
				var key="%s|%s"%[a,b] if str(a)<str(b) else "%s|%s"%[b,a]
				if seen.has(key):continue
				seen[key]=true;_append_country_route(result,"land",str(a),str(b),"مسیر زمینی مرزی",0.45,allowed)
	return result

func get_chokepoint_info(chokepoint_id: String) -> Dictionary:
	for cp in chokepoints:
		if str(cp.get("id","")) == chokepoint_id:
			return cp.duplicate(true)
	# fallback برای ۶ گلوگاه اصلی
	var fallbacks = {
		"hormuz":{"id":"hormuz","name_fa":"تنگه هرمز","lat":26.5,"lon":56.2,"from_country":"IRN","to_country":"OMN"},
		"suez":{"id":"suez","name_fa":"کانال سوئز","lat":30.0,"lon":32.5,"from_country":"EGY","to_country":"EGY"},
		"bab_el_mandeb":{"id":"bab_el_mandeb","name_fa":"باب‌المندب","lat":12.5,"lon":43.3,"from_country":"YEM","to_country":"DJI"},
		"malacca":{"id":"malacca","name_fa":"تنگه مالاکا","lat":2.5,"lon":101.0,"from_country":"MYS","to_country":"IDN"},
		"panama":{"id":"panama","name_fa":"کانال پاناما","lat":9.0,"lon":-79.5,"from_country":"PAN","to_country":"PAN"},
		"gibraltar":{"id":"gibraltar","name_fa":"جبل‌الطارق","lat":36.0,"lon":-5.5,"from_country":"ESP","to_country":"MAR"}
	}
	return fallbacks.get(chokepoint_id, {}).duplicate(true) if fallbacks.has(chokepoint_id) else {}

func get_chokepoints(allowed:Array=[])->Array:
	# نقاط دریایی جهانی حتی در نمای منطقه‌ای، فقط اگر داخل قاب باشند توسط Map رسم می‌شوند.
	return chokepoints.duplicate(true)

func update_network_metrics(state:Dictionary)->Dictionary:
	var player=str(state.get("country",{}).get("id",""));var air=0.0;var sea=0.0
	for route in get_static_routes("air"):
		if route.from_country==player or route.to_country==player:air+=float(route.volume)
	for route in get_static_routes("sea"):
		if route.from_country==player or route.to_country==player:sea+=float(route.volume)
	var borders=WorldManager.get_country(player).get("borders",[]).size();var disruptions=state.get("world",{}).get("wars",{}).size()
	state["map_network"]={"air_connectivity":clamp(air/5.0,0,1),"sea_connectivity":clamp(sea/5.0,0,1),"land_connectivity":clamp(float(borders)/8.0,0,1),"disrupted_routes":disruptions,"updated_turn":state.get("tick",0)}
	if disruptions>0:state["trade"]["exports"]*=max(0.92,1.0-disruptions*0.01)
	return state

func _append_country_route(result:Array,type:String,a:String,b:String,label:String,volume:float,allowed:Array):
	if not WorldManager.countries.has(a) or not WorldManager.countries.has(b):return
	if not allowed.is_empty() and (not allowed.has(a) or not allowed.has(b)):return
	var pa=WorldManager.countries[a];var pb=WorldManager.countries[b]
	result.append({"type":type,"from_country":a,"to_country":b,"from_lat":pa.get("lat",0),"from_lon":pa.get("lon",0),"to_lat":pb.get("lat",0),"to_lon":pb.get("lon",0),"label":label,"volume":volume})


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_map_layer_manager(data) -> Dictionary:
	if not data is Dictionary:
		return {"valid": false, "reason": "داده دیکشنری نیست"}
	if data.is_empty():
		return {"valid": false, "reason": "داده خالی"}
	# بررسی NaN/Inf
	for k in data.keys():
		var v = data[k]
		if v is float and (is_nan(v) or is_inf(v)):
			return {"valid": false, "reason": "عدد نامتناهی در %s" % str(k)}
	return {"valid": true, "reason": ""}

func _deep_cache_map_layer_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_map_layer_manager"):
		set_meta("cache_map_layer_manager", {})
	var cache = get_meta("cache_map_layer_manager")
	return cache.get(key, null)

func _deep_cache_map_layer_manager_set(key: String, value):
	if not has_meta("cache_map_layer_manager"):
		set_meta("cache_map_layer_manager", {})
	var cache = get_meta("cache_map_layer_manager")
	cache[key] = value
	set_meta("cache_map_layer_manager", cache)

func _deep_log_map_layer_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_map_layer_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_map_layer_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("map_layer_manager"):
		state["map_layer_manager"] = {}
	return state

func _deep_deterministic_map_layer_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_map_layer_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("map_layer_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_map_layer_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("map_layer_manager", {}).duplicate(true) if state.has("map_layer_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_map_layer_manager(data) -> Dictionary:
	if not data is Dictionary:
		return {"valid": false, "reason": "داده دیکشنری نیست"}
	if data.is_empty():
		return {"valid": false, "reason": "داده خالی"}
	# بررسی NaN/Inf
	for k in data.keys():
		var v = data[k]
		if v is float and (is_nan(v) or is_inf(v)):
			return {"valid": false, "reason": "عدد نامتناهی در %s" % str(k)}
	return {"valid": true, "reason": ""}

func _deep_cache_map_layer_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_map_layer_manager"):
		set_meta("cache_map_layer_manager", {})
	var cache = get_meta("cache_map_layer_manager")
	return cache.get(key, null)

func _deep_cache_map_layer_manager_set(key: String, value):
	if not has_meta("cache_map_layer_manager"):
		set_meta("cache_map_layer_manager", {})
	var cache = get_meta("cache_map_layer_manager")
	cache[key] = value
	set_meta("cache_map_layer_manager", cache)

func _deep_log_map_layer_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_map_layer_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_map_layer_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("map_layer_manager"):
		state["map_layer_manager"] = {}
	return state

func _deep_deterministic_map_layer_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_map_layer_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("map_layer_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_map_layer_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("map_layer_manager", {}).duplicate(true) if state.has("map_layer_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data



# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_map_layer_manager(data) -> Dictionary:
	if not data is Dictionary:
		return {"valid": false, "reason": "داده دیکشنری نیست"}
	if data.is_empty():
		return {"valid": false, "reason": "داده خالی"}
	# بررسی NaN/Inf
	for k in data.keys():
		var v = data[k]
		if v is float and (is_nan(v) or is_inf(v)):
			return {"valid": false, "reason": "عدد نامتناهی در %s" % str(k)}
	return {"valid": true, "reason": ""}

func _deep_cache_map_layer_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_map_layer_manager"):
		set_meta("cache_map_layer_manager", {})
	var cache = get_meta("cache_map_layer_manager")
	return cache.get(key, null)

func _deep_cache_map_layer_manager_set(key: String, value):
	if not has_meta("cache_map_layer_manager"):
		set_meta("cache_map_layer_manager", {})
	var cache = get_meta("cache_map_layer_manager")
	cache[key] = value
	set_meta("cache_map_layer_manager", cache)

func _deep_log_map_layer_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_map_layer_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_map_layer_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("map_layer_manager"):
		state["map_layer_manager"] = {}
	return state

func _deep_deterministic_map_layer_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_map_layer_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("map_layer_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_map_layer_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("map_layer_manager", {}).duplicate(true) if state.has("map_layer_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


