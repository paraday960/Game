extends Node
# کمپین چندکشوری Host-authoritative: هر بازیکن State مستقل و فرمان‌های مخصوص کشور خود دارد.

const MAX_HUMAN_COUNTRIES = 8
const GameCommandClass = preload("res://scripts/core/command.gd")

var active := false
var started := false
var campaign_turn := 0
var peer_registry: Dictionary = {} # peer_id -> {name,country_id,ready}
var country_states: Dictionary = {} # country_id -> full State
var pending_by_country: Dictionary = {}
# ردیابی پایان نوبت جاری: country_id -> true
var turn_finished: Dictionary = {}
# پیام‌های چت درون‌بازی (حلقه‌ای برای جلوگیری از رشد بی‌نهایت)
const MAX_CHAT_MESSAGES := 200
var chat_messages: Array = []

signal lobby_changed(lobby)
signal campaign_advanced(turn)
signal turn_finished_changed(finished_map)
signal chat_message_received(message)

func reset():
	active=false;started=false;campaign_turn=0
	peer_registry.clear();country_states.clear();pending_by_country.clear()
	turn_finished.clear();chat_messages.clear()

# ── پایان نوبت همگام ──
# بازیکنی که دستورات خود را ثبت کرده «پایان نوبت» می‌زند. نوبت تنها وقتی
# جلو می‌رود که همه کشورهای انسانی پایان نوبت را علامت زده باشند.
func mark_turn_finished(peer_id: String) -> Dictionary:
	if not started or not peer_registry.has(peer_id):
		return {"success": false, "reason": "بازیکن عضو کمپین فعال نیست"}
	var country_id := str(peer_registry[peer_id].get("country_id", ""))
	turn_finished[country_id] = true
	var snap := get_turn_finished_snapshot()
	emit_signal("turn_finished_changed", snap)
	return {"success": true, "finished": snap.duplicate(true), "all_finished": all_turns_finished()}

func unmark_turn_finished(peer_id: String):
	if not peer_registry.has(peer_id): return
	var country_id := str(peer_registry[peer_id].get("country_id", ""))
	turn_finished.erase(country_id)
	emit_signal("turn_finished_changed", get_turn_finished_snapshot())

func all_turns_finished() -> bool:
	if not started or peer_registry.is_empty(): return false
	for player in peer_registry.values():
		var cid := str(player.get("country_id", ""))
		if not turn_finished.get(cid, false):
			return false
	return true

func get_turn_finished_snapshot() -> Dictionary:
	# نگاشت country_id -> {name, finished} برای نمایش پنجره
	var snap: Dictionary = {}
	for player in peer_registry.values():
		var cid := str(player.get("country_id", ""))
		snap[cid] = {
			"name": str(player.get("name", "بازیکن")),
			"finished": bool(turn_finished.get(cid, false))
		}
	return snap

func has_finished(peer_id: String) -> bool:
	if not peer_registry.has(peer_id): return false
	return bool(turn_finished.get(str(peer_registry[peer_id].get("country_id", "")), false))

func create_lobby(host_peer_id:String,player_name:String,country_id:String)->Dictionary:
	reset();active=true
	return register_peer(host_peer_id,player_name,country_id)

func register_peer(peer_id:String,player_name:String,country_id:String)->Dictionary:
	if started:return {"success":false,"reason":"کمپین آغاز شده و ورود جدید بسته است"}
	if peer_registry.size()>=MAX_HUMAN_COUNTRIES:return {"success":false,"reason":"ظرفیت کمپین تکمیل است"}
	if not WorldManager.countries.has(country_id):return {"success":false,"reason":"کشور انتخابی وجود ندارد"}
	for existing in peer_registry.values():
		if existing.get("country_id","")==country_id:return {"success":false,"reason":"این کشور توسط بازیکن دیگری انتخاب شده است"}
	peer_registry[peer_id]={"name":player_name.strip_edges() if not player_name.strip_edges().is_empty() else "بازیکن","country_id":country_id,"ready":false}
	emit_signal("lobby_changed",get_lobby_snapshot())
	return {"success":true,"peer_id":peer_id,"country_id":country_id}

func unregister_peer(peer_id:String):
	if started:return
	peer_registry.erase(peer_id);emit_signal("lobby_changed",get_lobby_snapshot())

func set_ready(peer_id:String,value:bool)->bool:
	if not peer_registry.has(peer_id) or started:return false
	peer_registry[peer_id]["ready"]=value;emit_signal("lobby_changed",get_lobby_snapshot());return true

func all_ready()->bool:
	if peer_registry.size()<2:return false
	for player in peer_registry.values():
		if not player.get("ready",false):return false
	return true

func start_campaign(base_state:Dictionary)->Dictionary:
	if started:return {"success":false,"reason":"کمپین قبلاً آغاز شده است"}
	if not all_ready():return {"success":false,"reason":"همه بازیکنان آماده نیستند"}
	country_states.clear();pending_by_country.clear();campaign_turn=0;turn_finished.clear();chat_messages.clear()
	for player in peer_registry.values():
		var country_id=str(player.get("country_id",""));country_states[country_id]=_create_country_state(base_state,country_id);pending_by_country[country_id]=[]
	started=true;emit_signal("lobby_changed",get_lobby_snapshot());return {"success":true,"countries":country_states.size()}

func enqueue_command(peer_id:String,command)->Dictionary:
	if not started or not peer_registry.has(peer_id):return {"success":false,"reason":"بازیکن عضو کمپین فعال نیست"}
	if command==null or not command.has_method("to_dict"):return {"success":false,"reason":"فرمان نامعتبر است"}
	var country_id=str(peer_registry[peer_id]["country_id"]);command.player_id=peer_id
	pending_by_country[country_id].append(command);return {"success":true}

func advance_month()->Dictionary:
	if not started:return {"success":false,"reason":"کمپین آغاز نشده است"}
	if not all_turns_finished():
		return {"success":false,"reason":"هنوز همه بازیکنان پایان نوبت را نزدند","waiting":get_turn_finished_snapshot()}
	campaign_turn+=1
	var results:Dictionary={}
	var ids=country_states.keys();ids.sort()
	for country_id in ids:
		var state:Dictionary=country_states[country_id];var commands:Array=pending_by_country.get(country_id,[]).duplicate();commands.append(GameCommandClass.create_next_tick())
		var result=GameEngine.tick(state,int(state.get("version",0)),int(state.get("tick",0)),commands)
		if not result.success:return {"success":false,"reason":"کشور %s: %s"%[WorldManager.get_country_name(country_id),result.reason],"country_id":country_id}
		country_states[country_id]=result.state;pending_by_country[country_id]=[];results[country_id]=result
	_reconcile_human_countries()
	# همه نوبت‌ها اجرا شد؛ پرچم‌ها برای نوبت بعد صفر شوند
	turn_finished.clear()
	emit_signal("campaign_advanced",campaign_turn)
	emit_signal("turn_finished_changed",get_turn_finished_snapshot())
	return {"success":true,"turn":campaign_turn,"states":country_states.duplicate(true),"results":results}

# ── چت درون‌بازی ──
func add_chat_message(peer_id: String, text: String, msg_type: String = "chat") -> Dictionary:
	var clean := text.strip_edges() if text != null else ""
	if clean.length() == 0:
		return {"success": false, "reason": "پیام خالی است"}
	if clean.length() > 500:
		clean = clean.substr(0, 500)
	var player_name := "بازیکن"
	if peer_registry.has(peer_id):
		player_name = str(peer_registry[peer_id].get("name", "بازیکن"))
	var country_id := str(peer_registry.get(peer_id, {}).get("country_id", ""))
	var msg := {
		"peer_id": peer_id,
		"name": player_name,
		"country_id": country_id,
		"text": clean,
		"type": msg_type,
		"turn": campaign_turn,
		"timestamp": Time.get_unix_time_from_system()
	}
	chat_messages.append(msg)
	if chat_messages.size() > MAX_CHAT_MESSAGES:
		chat_messages.pop_front()
	emit_signal("chat_message_received", msg)
	return {"success": true, "message": msg}

func get_recent_chat(count: int = 50) -> Array:
	if chat_messages.size() <= count:
		return chat_messages.duplicate()
	return chat_messages.slice(chat_messages.size() - count)

func get_state_for_peer(peer_id:String)->Dictionary:
	if not peer_registry.has(peer_id):return {}
	return country_states.get(str(peer_registry[peer_id].get("country_id","")),{}).duplicate(true)

func get_country_for_peer(peer_id:String)->String:
	return str(peer_registry.get(peer_id,{}).get("country_id",""))

func get_lobby_snapshot()->Dictionary:
	return {"active":active,"started":started,"turn":campaign_turn,"players":peer_registry.duplicate(true),"max_players":MAX_HUMAN_COUNTRIES}

func _create_country_state(base_state:Dictionary,country_id:String)->Dictionary:
	var state=base_state.duplicate(true);state["version"]=0;state["tick"]=0;state["command_receipts"]=[]
	state=WorldManager.apply_country_profile(state,country_id);state=TimeManager.reset(state);state=SeasonalManager.reset_for_country(state,country_id)
	state=MilitaryManager.reset(state);state=NationalProjectManager.reset(state);state=CabinetManager.reset(state);state=LawManager.reset(state);state=IntelligenceOperationManager.reset(state)
	state=ScenarioManager.apply_scenario(state,ScenarioManager.default_scenario,0);state=PolicyManager.reset(state);state=AnalyticsManager.reset(state);state=AuditManager.reset(state)
	return state

func _reconcile_human_countries():
	var ids=country_states.keys();ids.sort()
	# شاخص واقعی هر کشور انسانی در جهان همه بازیکنان بازتاب می‌یابد.
	for viewer_id in ids:
		var viewer:Dictionary=country_states[viewer_id]
		for country_id in ids:
			if country_id==viewer_id:continue
			var live:Dictionary=country_states[country_id]
			if viewer.get("world",{}).get("countries",{}).has(country_id):
				var runtime:Dictionary=viewer["world"]["countries"][country_id]
				runtime["gdp"]=live["economy"].get("gdp",runtime.get("gdp",0));runtime["population"]=live["population"].get("total",runtime.get("population",0));runtime["military_power"]=live["military"].get("power",runtime.get("military_power",0));runtime["tech_level"]=_average_branch(live)
				viewer["world"]["countries"][country_id]=runtime
		country_states[viewer_id]=viewer
	# روابط و پیمان‌های دوطرفه میان انسان‌ها همگام می‌شوند.
	for i in range(ids.size()):
		for j in range(i+1,ids.size()):
			var a=str(ids[i]);var b=str(ids[j]);var sa:Dictionary=country_states[a];var sb:Dictionary=country_states[b]
			var relation=(float(sa["diplomacy"]["relations"].get(b,50))+float(sb["diplomacy"]["relations"].get(a,50)))*0.5
			sa["diplomacy"]["relations"][b]=relation;sb["diplomacy"]["relations"][a]=relation
			_sync_pair_list(sa,sb,"alliances",a,b);_sync_pair_list(sa,sb,"trade_agreements",a,b)
			country_states[a]=sa;country_states[b]=sb

func _sync_pair_list(a_state:Dictionary,b_state:Dictionary,key:String,a:String,b:String):
	var active=a_state.get("world",{}).get(key,[]).has(b) or b_state.get("world",{}).get(key,[]).has(a)
	if active:
		if not a_state["world"][key].has(b):a_state["world"][key].append(b)
		if not b_state["world"][key].has(a):b_state["world"][key].append(a)

func _average_branch(state:Dictionary)->float:
	var branches:Dictionary=state.get("technology",{}).get("branches",{});var total=0.0
	for value in branches.values():total+=float(value)
	return total/max(branches.size(),1)
