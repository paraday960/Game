extends Node
# عملیات اطلاعاتی زمان‌دار با هزینه، موفقیت، خطر افشا و پیامد دیپلماتیک

const DATA_PATH = "res://data/intelligence_operations.json"
var operations: Dictionary = {}
var ordered_ids: Array = []
var data_version := ""
var load_errors: Array = []

func _ready():
	reload()

func reload() -> bool:
	operations.clear(); ordered_ids.clear(); load_errors.clear()
	var file=FileAccess.open(DATA_PATH,FileAccess.READ)
	if file==null: load_errors.append("فایل عملیات اطلاعاتی خوانده نشد"); return false
	var parsed=JSON.parse_string(file.get_as_text()); file.close()
	if not parsed is Dictionary or not parsed.get("operations",null) is Array: load_errors.append("ساختار عملیات اطلاعاتی نامعتبر است"); return false
	data_version=str(parsed.get("version","1.0.0"))
	for raw in parsed["operations"]:
		if not raw is Dictionary: continue
		var id=str(raw.get("id",""))
		if id.is_empty() or operations.has(id): load_errors.append("شناسه عملیات اطلاعاتی تکراری است"); continue
		operations[id]=raw.duplicate(true); ordered_ids.append(id)
	return load_errors.is_empty()

func is_valid()->bool: return operations.size()>=8 and load_errors.is_empty()
func get_operation_ids()->Array: return ordered_ids.duplicate()
func get_operation(id:String)->Dictionary: return operations.get(id,{}).duplicate(true)
func get_operation_name(id:String)->String: return str(operations.get(id,{}).get("name_fa",id))

func reset(state:Dictionary)->Dictionary:
	state["intelligence_operations"]={"data_version":data_version,"active":{},"history":[],"reports":[],"heat":0.0,"capacity":2}
	return state

func ensure_state(state:Dictionary)->Dictionary:
	if not state.has("intelligence_operations") or not state["intelligence_operations"] is Dictionary: return reset(state)
	var io:Dictionary=state["intelligence_operations"]
	io["active"]=io.get("active",{});io["history"]=io.get("history",[]);io["reports"]=io.get("reports",[]);io["heat"]=float(io.get("heat",0.0));io["capacity"]=int(io.get("capacity",2))
	state["intelligence_operations"]=io;return state

func can_start(state:Dictionary,id:String,target:String="")->Dictionary:
	if not operations.has(id): return {"valid":false,"reason":"عملیات اطلاعاتی وجود ندارد"}
	state=ensure_state(state.duplicate(true));var io:Dictionary=state["intelligence_operations"];var definition:Dictionary=operations[id]
	if io["active"].size()>=int(io.get("capacity",2)): return {"valid":false,"reason":"ظرفیت عملیاتی سازمان اطلاعات تکمیل است"}
	for record in io["active"].values():
		if record.get("operation_id","")==id and record.get("target","")==target: return {"valid":false,"reason":"همین عملیات در حال اجراست"}
	if definition.get("scope","domestic")=="foreign":
		if target.is_empty() or not WorldManager.countries.has(target) or target==state.get("country",{}).get("id",""): return {"valid":false,"reason":"کشور هدف عملیات معتبر نیست"}
	for prerequisite in definition.get("prerequisites",[]):
		if not state.get("technology",{}).get("unlocked",[]).has(prerequisite): return {"valid":false,"reason":"فناوری پیش‌نیاز «%s» باز نشده است"%TechnologyManager.get_technology_name(prerequisite)}
	return {"valid":true,"reason":""}

func start(state:Dictionary,id:String,target:String,turn:int)->Dictionary:
	var check=can_start(state,id,target)
	if not check.valid:return {"success":false,"reason":check.reason,"state":state,"events":[]}
	state=ensure_state(state);var io:Dictionary=state["intelligence_operations"];var definition:Dictionary=operations[id]
	var key="%s:%s:%d"%[id,target,turn];var cost=float(state["economy"].get("gdp",1.0))*float(definition.get("cost_gdp_ratio",0.001))
	state["economy"]["national_debt"]=float(state["economy"].get("national_debt",0.0))+cost
	io["active"][key]={"operation_id":id,"target":target,"started_turn":turn,"remaining_months":int(definition.get("duration_months",1)),"cost":cost}
	io["heat"]=clamp(float(io["heat"])+0.04,0,1);io["history"].append({"type":"started","operation_id":id,"target":target,"turn":turn})
	state["intelligence_operations"]=io
	return {"success":true,"state":state,"events":[{"type":"intelligence_operation_started","message":"عملیات «%s» آغاز شد"%get_operation_name(id)}]}

func cancel(state:Dictionary,key:String,turn:int)->Dictionary:
	state=ensure_state(state);var io:Dictionary=state["intelligence_operations"]
	if not io["active"].has(key):return {"success":false,"reason":"عملیات فعال یافت نشد","state":state,"events":[]}
	var record=io["active"][key];io["active"].erase(key);io["history"].append({"type":"cancelled","operation_id":record.get("operation_id",""),"target":record.get("target",""),"turn":turn});state["intelligence_operations"]=io
	return {"success":true,"state":state,"events":[{"type":"intelligence_operation_cancelled","message":"عملیات «%s» لغو شد"%get_operation_name(str(record.get("operation_id","")))}]}

func simulate_month(state:Dictionary,turn:int,forced:Dictionary={})->Dictionary:
	state=ensure_state(state);var io:Dictionary=state["intelligence_operations"];var events:Array=[];var finished:Array=[]
	io["heat"]=max(0.0,float(io["heat"])-0.03)
	for key in io["active"].keys():
		io["active"][key]["remaining_months"]=int(io["active"][key].get("remaining_months",1))-1
		if int(io["active"][key]["remaining_months"])<=0:finished.append(key)
	for key in finished:
		var record:Dictionary=io["active"][key];io["active"].erase(key)
		var id=str(record.get("operation_id",""));var target=str(record.get("target",""));var definition:Dictionary=operations[id]
		var quality=clamp(float(state.get("intelligence",{}).get("power",50.0))/100.0*0.45+float(state.get("intelligence",{}).get("cyber_readiness",0.5))*0.25+float(state.get("education",{}).get("quality",0.5))*0.20+0.10,0,1)
		var success_chance=clamp(float(definition.get("base_success",0.6))*0.65+quality*0.35-float(io["heat"])*0.12,0.08,0.95)
		var success=bool(forced.get("force_success",Deterministic.chance(success_chance)))
		var detection_chance=clamp(float(definition.get("detection_risk",0.2))*(1.15-quality*0.45)+float(io["heat"])*0.20,0.01,0.90)
		var detected=bool(forced.get("force_detected",Deterministic.chance(detection_chance)))
		if success:_apply_success(state,id,target,definition,quality,turn,io);events.append({"type":"intelligence_operation_success","operation_id":id,"target":target,"message":"عملیات «%s» با موفقیت پایان یافت"%get_operation_name(id)})
		else:events.append({"type":"intelligence_operation_failed","operation_id":id,"target":target,"message":"عملیات «%s» بدون دستیابی به هدف پایان یافت"%get_operation_name(id)})
		if detected and definition.get("scope","domestic")=="foreign":_apply_detection(state,id,target,io);events.append({"type":"intelligence_operation_exposed","operation_id":id,"target":target,"message":"عملیات «%s» در %s افشا شد و پیامد دیپلماتیک ایجاد کرد"%[get_operation_name(id),WorldManager.get_country_name(target)]})
		io["history"].append({"type":"completed","operation_id":id,"target":target,"turn":turn,"success":success,"detected":detected})
	while io["history"].size()>150:io["history"].pop_front()
	while io["reports"].size()>50:io["reports"].pop_front()
	state["intelligence_operations"]=io
	return {"state":state,"events":events}

func get_recon_bonus(state:Dictionary,target:String)->float:
	for report in state.get("intelligence_operations",{}).get("reports",[]):
		if report.get("type","")=="military_recon" and report.get("target","")==target and int(report.get("expires_turn",0))>=int(state.get("tick",0)):return float(report.get("quality",0.0))*0.12
	return 0.0

func _apply_success(state:Dictionary,id:String,target:String,definition:Dictionary,quality:float,turn:int,io:Dictionary):
	for effect in definition.get("effects",[]):_apply_effect(state,effect)
	if id=="foreign_intelligence":
		var profile=state.get("world",{}).get("countries",{}).get(target,{});io["reports"].append({"type":"foreign_intelligence","target":target,"quality":quality,"turn":turn,"expires_turn":turn+12,"gdp":profile.get("gdp",0),"military_power":profile.get("military_power",0),"tech_level":profile.get("tech_level",0)})
	elif id=="military_recon":io["reports"].append({"type":"military_recon","target":target,"quality":quality,"turn":turn,"expires_turn":turn+12})
	elif id=="influence_campaign":state["diplomacy"]["relations"][target]=clamp(float(state["diplomacy"]["relations"].get(target,50))+8.0,0,100)
	elif id=="covert_diplomacy":state["diplomacy"]["relations"][target]=clamp(float(state["diplomacy"]["relations"].get(target,50))+10.0,0,100)
	elif id=="sanctions_network":_remove_one_incoming_sanction(state,target)

func _apply_detection(state:Dictionary,id:String,target:String,io:Dictionary):
	io["heat"]=clamp(float(io["heat"])+0.22,0,1);state["diplomacy"]["relations"][target]=clamp(float(state["diplomacy"]["relations"].get(target,50))-12.0,0,100);state["politics"]["tension"]=clamp(float(state["politics"].get("tension",0.3))+0.025,0,1)
	if id in ["technology_acquisition","influence_campaign"] and Deterministic.chance(0.45):state["diplomacy"]["sanctions"].append({"target":target,"by":"foreign","reason":"عملیات اطلاعاتی افشاشده"})

func _remove_one_incoming_sanction(state:Dictionary,target:String):
	var kept:Array=[];var removed=false
	for sanction in state["diplomacy"].get("sanctions",[]):
		if not removed and sanction is Dictionary and sanction.get("target","")==target and sanction.get("by","foreign")!="player":removed=true;continue
		kept.append(sanction)
	state["diplomacy"]["sanctions"]=kept

func _apply_effect(state:Dictionary,effect:Dictionary):
	var parts=str(effect.get("path","")).split(".");var current=state
	for i in range(parts.size()-1):
		if not current is Dictionary or not current.has(parts[i]):return
		current=current[parts[i]]
	var key=parts[-1]
	if not current is Dictionary or not current.has(key) or not (current[key] is int or current[key] is float):return
	var value=float(current[key])+float(effect.get("value",0.0))
	if effect.has("min"):value=max(value,float(effect["min"]))
	if effect.has("max"):value=min(value,float(effect["max"]))
	current[key]=value


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_intelligence_operation_manager(data) -> Dictionary:
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

func _deep_cache_intelligence_operation_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_intelligence_operation_manager"):
		set_meta("cache_intelligence_operation_manager", {})
	var cache = get_meta("cache_intelligence_operation_manager")
	return cache.get(key, null)

func _deep_cache_intelligence_operation_manager_set(key: String, value):
	if not has_meta("cache_intelligence_operation_manager"):
		set_meta("cache_intelligence_operation_manager", {})
	var cache = get_meta("cache_intelligence_operation_manager")
	cache[key] = value
	set_meta("cache_intelligence_operation_manager", cache)

func _deep_log_intelligence_operation_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_intelligence_operation_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_intelligence_operation_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("intelligence_operation_manager"):
		state["intelligence_operation_manager"] = {}
	return state

func _deep_deterministic_intelligence_operation_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_intelligence_operation_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("intelligence_operation_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_intelligence_operation_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("intelligence_operation_manager", {}).duplicate(true) if state.has("intelligence_operation_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_intelligence_operation_manager(data) -> Dictionary:
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

func _deep_cache_intelligence_operation_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_intelligence_operation_manager"):
		set_meta("cache_intelligence_operation_manager", {})
	var cache = get_meta("cache_intelligence_operation_manager")
	return cache.get(key, null)

func _deep_cache_intelligence_operation_manager_set(key: String, value):
	if not has_meta("cache_intelligence_operation_manager"):
		set_meta("cache_intelligence_operation_manager", {})
	var cache = get_meta("cache_intelligence_operation_manager")
	cache[key] = value
	set_meta("cache_intelligence_operation_manager", cache)

func _deep_log_intelligence_operation_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_intelligence_operation_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_intelligence_operation_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("intelligence_operation_manager"):
		state["intelligence_operation_manager"] = {}
	return state

func _deep_deterministic_intelligence_operation_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_intelligence_operation_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("intelligence_operation_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_intelligence_operation_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("intelligence_operation_manager", {}).duplicate(true) if state.has("intelligence_operation_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data



# --- لایه عمیق: اعتبارسنجی، کش، لاگ، نسخه‌بندی، دترمینستیک، بازیابی خطا ---

func _deep_validate_intelligence_operation_manager(data) -> Dictionary:
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

func _deep_cache_intelligence_operation_manager_get(key: String):
	# کش ساده درون‌حافظه‌ای برای بهبود کارایی - دترمینستیک
	if not has_meta("cache_intelligence_operation_manager"):
		set_meta("cache_intelligence_operation_manager", {})
	var cache = get_meta("cache_intelligence_operation_manager")
	return cache.get(key, null)

func _deep_cache_intelligence_operation_manager_set(key: String, value):
	if not has_meta("cache_intelligence_operation_manager"):
		set_meta("cache_intelligence_operation_manager", {})
	var cache = get_meta("cache_intelligence_operation_manager")
	cache[key] = value
	set_meta("cache_intelligence_operation_manager", cache)

func _deep_log_intelligence_operation_manager(event_type: String, data: Dictionary, tick: int):
	# لاگ ساختاریافته برای EventLog
	if Engine.has_singleton("EventLog"):
		var EventLog = Engine.get_singleton("EventLog")
		if EventLog.has_method("log_event"):
			EventLog.log_event(event_type, data, tick, 0)

func _deep_version_check_intelligence_operation_manager(state: Dictionary) -> bool:
	# بررسی سازگاری نسخه اسکیما
	var schema = int(state.get("schema_version", 0))
	return schema >= 15 # حداقل نسخه قابل قبول

func _deep_recover_intelligence_operation_manager(state: Dictionary) -> Dictionary:
	# بازیابی از حالت خراب - تلاش برای بازسازی کلیدهای حیاتی
	if not state.has("intelligence_operation_manager"):
		state["intelligence_operation_manager"] = {}
	return state

func _deep_deterministic_intelligence_operation_manager_hash(data) -> int:
	# هش دترمینستیک برای ضدتقلب و همگام‌سازی شبکه
	var s = str(data)
	var h = 0
	for i in range(s.length()):
		h = (h * 31 + s.unicode_at(i)) % 1000000007
	return h

func _deep_analytics_intelligence_operation_manager(state: Dictionary) -> Dictionary:
	# تحلیل روند و پیش‌بینی ساده
	var history = state.get("intelligence_operation_manager_history", [])
	if history is Array and history.size() > 5:
		var trend = 0.0
		for i in range(1, min(5, history.size())):
			var curr = float(history[-i]) if history[-i] is float or history[-i] is int else 0.0
			var prev = float(history[-i-1]) if history[-i-1] is float or history[-i-1] is int else 0.0
			trend += (curr - prev)
		return {"trend": trend / 5.0, "samples": history.size()}
	return {"trend": 0.0, "samples": 0}

func _deep_export_intelligence_operation_manager(state: Dictionary) -> Dictionary:
	# خروجی برای ذخیره و شبکه - فشرده و نسخه‌دار
	var data = state.get("intelligence_operation_manager", {}).duplicate(true) if state.has("intelligence_operation_manager") else {}
	data["export_tick"] = state.get("tick", 0)
	data["export_version"] = state.get("version", 0)
	return data


