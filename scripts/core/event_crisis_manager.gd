extends Node
# موتور رویدادها و بحران‌ها - آیتم ۴ رودمپ
# هر نوبت ماهانه، ریسک‌های کشور را به‌صورت دترمینستیک ارزیابی می‌کند و بحران‌ها را با چرخه‌ی
# حیات کامل (فعال‌شدن ← اثر ماهانه ماندگار ← پایان و فرسایش ← دوره تامین مجدد) مدیریت می‌کند.
# بحران‌های فعال در events_active ذخیره می‌شوند (قبلاً این کلید تعریف شده ولی بلااستفاده بود).
# نوع رویدادها با قالب‌های DecisionManager سازگار است، پس هر بحران به‌صورت خودکار به یک
# تصمیم چندگزینه‌ای فارسی برای بازیکن تبدیل می‌شود و انقضای آن پیامد پیش‌فرض دارد.

const MAX_ACTIVE_CRISES = 4
const COOLDOWN_DAYS = 120

# ── نخ‌های بحران (Crisis Threads) — بازرسی ۱۴۰۵ دور سیزدهم ────────────────
# رویدادهای واقعی زنجیره‌ای‌اند نه تک‌ضربه: خشکسالی ← تورم خوراک ← فشار ارزی.
# هر زنجیره چند مرحله دارد؛ هر مرحله اثر ماهانه‌ی واقعی روی state، شرط/زمان
# پیشروی، نقطه‌ی تصمیم فارسی (قالب DecisionManager) و گاهی اثر جهانی (کالاها)
# دارد. تعریف‌ها داده‌محور در data/crisis_chains.json نگهداری می‌شوند.
const CHAINS_PATH = "res://data/crisis_chains.json"
var chains: Array = []
var load_errors: Array = []

func _ready():
	reload()

func reload() -> bool:
	chains.clear()
	load_errors.clear()
	var file = FileAccess.open(CHAINS_PATH, FileAccess.READ)
	if file == null:
		load_errors.append("فایل زنجیره‌های بحران خوانده نشد")
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or not parsed.get("chains", null) is Array:
		load_errors.append("ساختار crisis_chains.json نامعتبر است")
		return false
	for raw in parsed["chains"]:
		if not raw is Dictionary or str(raw.get("id", "")).is_empty():
			load_errors.append("زنجیرهٔ بحران با شناسهٔ نامعتبر")
			continue
		chains.append(raw.duplicate(true))
	return load_errors.is_empty()

func _chain_by_id(id: String) -> Dictionary:
	for chain in chains:
		if str(chain.get("id", "")) == id:
			return chain
	return {}

# تعریف داده‌محور بحران‌ها؛ ترتیب ثابت آرایه برای قطعی‌بودن ترتیب ارزیابی (و در نتیجه
# مصرف یکسان اعداد دترمینستیک در همه دستگاه‌ها) حیاتی است.
# trigger_mode: «all» همه شرط‌ها باید برقرار باشند، «any» برقراری هرکدام کافی است.
# chance: شانس ماهانه وقوع پس از برقرار بودن شرط‌ها (در هر نوبت یک‌بار).
# immediate_effects: اثر یک‌باره هنگام وقوع | persist_effects: اثر ماهانه در طول فعال‌بودن.
const CRISES = [
	{
		"type": "mass_protest",
		"title": "اعتراضات گسترده",
		"severity": 3,
		"trigger_mode": "any",
		"trigger": [
			{"path": "population.happiness", "op": "<", "value": 0.40},
			{"path": "politics.tension", "op": ">", "value": 0.55}
		],
		"chance": 0.35,
		"duration_days": 90,
		"persist_effects": [
			{"path": "politics.stability", "op": "add", "value": -0.01, "min": 0.0, "max": 1.0},
			{"path": "population.happiness", "op": "add", "value": -0.005, "min": 0.05, "max": 0.95}
		]
	},
	{
		"type": "debt_crisis",
		"title": "بحران بدهی دولت",
		"severity": 3,
		"trigger": [{"path": "economy.debt_to_gdp", "op": ">", "value": 1.3}],
		"chance": 0.40,
		"duration_days": 180,
		"persist_effects": [
			{"path": "economy.growth_rate", "op": "add", "value": -0.001, "min": -0.05, "max": 0.08},
			{"path": "stock_market.investor_confidence", "op": "add", "value": -0.01, "min": 0.0, "max": 1.0}
		]
	},
	{
		"type": "epidemic_outbreak",
		"title": "شیوع بیماری واگیردار",
		"severity": 3,
		"trigger": [{"path": "health.quality", "op": "<", "value": 0.45}],
		"chance": 0.25,
		"duration_days": 120,
		"persist_effects": [
			{"path": "health.quality", "op": "add", "value": -0.003, "min": 0.0, "max": 1.0},
			{"path": "population.happiness", "op": "add", "value": -0.004, "min": 0.05, "max": 0.95}
		]
	},
	{
		"type": "border_tension",
		"title": "تنش مرزی",
		"severity": 2,
		"trigger_mode": "any",
		"trigger": [
			{"path": "military.readiness", "op": "<", "value": 0.40},
			{"path": "diplomacy.influence", "op": "<", "value": 22.0}
		],
		"chance": 0.30,
		"duration_days": 90,
		"persist_effects": [
			{"path": "politics.tension", "op": "add", "value": 0.005, "min": 0.0, "max": 1.0},
			{"path": "military.readiness", "op": "add", "value": -0.002, "min": 0.1, "max": 1.0}
		]
	},
	{
		"type": "cyber_attack",
		"title": "حمله سایبری به زیرساخت‌ها",
		"severity": 2,
		"trigger": [{"path": "intelligence.cyber_readiness", "op": "<", "value": 0.45}],
		"chance": 0.20,
		"duration_days": 60,
		"persist_effects": [
			{"path": "statistics.digital", "op": "add", "value": -0.002, "min": 0.0, "max": 1.0},
			{"path": "administration.efficiency", "op": "add", "value": -0.002, "min": 0.0, "max": 1.0}
		]
	},
	{
		"type": "natural_disaster",
		"title": "بلای طبیعی بزرگ",
		"severity": 3,
		"trigger": [{"path": "emergency.preparedness", "op": "<", "value": 0.35}],
		"chance": 0.12,
		"duration_days": 45,
		"immediate_effects": [
			{"path": "infrastructure.quality", "op": "add", "value": -0.02, "min": 0.0, "max": 1.0},
			{"path": "economy.national_debt", "op": "add", "value": 3000000000.0, "min": 0.0}
		],
		"persist_effects": [
			{"path": "population.happiness", "op": "add", "value": -0.003, "min": 0.05, "max": 0.95}
		]
	},
	{
		"type": "trade_deficit_crisis",
		"title": "کسری شدید تجاری",
		"severity": 2,
		"trigger": [{"path": "trade.balance", "op": "<", "value": 0.0}],
		"chance": 0.30,
		"duration_days": 120,
		"persist_effects": [
			{"path": "central_bank.exchange_rate", "op": "mul", "value": 1.004, "min": 0.01},
			{"path": "stock_market.growth", "op": "add", "value": -0.001, "min": -0.5, "max": 0.5}
		]
	},
	{
		"type": "housing_crisis",
		"title": "بحران مسکن",
		"severity": 2,
		"trigger": [{"path": "physical.housing_shortage", "op": ">", "value": 0.20}],
		"chance": 0.30,
		"duration_days": 180,
		"persist_effects": [
			{"path": "population.happiness", "op": "add", "value": -0.003, "min": 0.05, "max": 0.95},
			{"path": "welfare.poverty", "op": "add", "value": 0.002, "min": 0.0, "max": 1.0}
		]
	},
	{
		"type": "brain_drain",
		"title": "موج مهاجرت نخبگان",
		"severity": 2,
		"trigger": [{"path": "elites_detail.brain_drain", "op": ">", "value": 0.25}],
		"chance": 0.25,
		"duration_days": 150,
		"persist_effects": [
			{"path": "technology.research_rate", "op": "add", "value": -0.05, "min": 0.0}
		]
	},
	{
		"type": "drought",
		"title": "خشکسالی گسترده",
		"severity": 2,
		"trigger_mode": "any",
		"trigger": [
			{"path": "resources.inventory.غذا", "op": "<", "value": 40.0},
			{"path": "agriculture.food_security", "op": "<", "value": 0.60}
		],
		"chance": 0.30,
		"duration_days": 120,
		"persist_effects": [
			{"path": "agriculture.food_security", "op": "add", "value": -0.004, "min": 0.0, "max": 1.0},
			{"path": "welfare.poverty", "op": "add", "value": 0.002, "min": 0.0, "max": 1.0}
		]
	}
]

# اعتبارسنجی ایستا: نوع هر بحران باید قالب تصمیم فارسی متناظر در DecisionManager داشته باشد.
func is_valid() -> bool:
	var DecisionManagerClass = preload("res://scripts/core/decision_manager.gd")
	for definition in CRISES:
		if not DecisionManagerClass.TEMPLATES.has(str(definition.get("type", ""))):
			return false
	for chain in chains:
		if not DecisionManagerClass.TEMPLATES.has(str(chain.get("entry_decision", ""))):
			return false
		for stage in chain.get("stages", []):
			if stage.has("decision") and not DecisionManagerClass.TEMPLATES.has(str(stage["decision"])):
				return false
	return true

const MAX_SCARS := 3

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state["events_active"] = state.get("events_active", [])
	state["crisis_cooldowns"] = state.get("crisis_cooldowns", {})
	state["crisis_scars"] = state.get("crisis_scars", [])
	var events: Array = []
	var current_day = TimeManager.get_total_days(state)

	# ۰) اسکارهای بحران (عمق‌بخشی ۵): اثر ماندگار پس از پایان نخ‌ها؛ هر ماه
	#     اثر دارند و پس از مدت محو می‌شوند (مثل بی‌اعتمادی اعتباریِ سال‌ها پس از
	#     بحران بانکی یا جهش بهره‌وریِ ماندگار پس از انقلاب AI).
	var kept_scars: Array = []
	for scar in state["crisis_scars"]:
		if current_day >= int(scar.get("expires_day", current_day + 1)):
			events.append({
				"type": "crisis_scar_healed",
				"title": str(scar.get("title_fa", "اسکار بحران")),
				"message": "اثر ماندگار «%s» پس از گذر زمان رو به بهبود رفت" % str(scar.get("title_fa", ""))
			})
			continue
		for effect in scar.get("effects", []):
			_apply_path_effect(state, effect)
		kept_scars.append(scar)
	state["crisis_scars"] = kept_scars

	# ۱) چرخه‌ی حیات بحران‌های فعال: اثر ماهانه، سپس پایان/پیشروی مرحله و ثبت دوره تامین مجدد
	var kept: Array = []
	for crisis in state["events_active"]:
		if str(crisis.get("status", "active")) != "active":
			continue
		var is_chain := int(crisis.get("stage_count", 0)) > 0
		var chain_def := _chain_by_id(str(crisis.get("type", ""))) if is_chain else {}
		if current_day >= int(crisis.get("expires_day", current_day + 1)):
			if is_chain and not chain_def.is_empty() \
					and int(crisis.get("stage", 0)) < int(crisis.get("stage_count", 0)) - 1:
				# ── پیشروی به مرحلهٔ بعدی نخ ──
				crisis["stage"] = int(crisis.get("stage", 0)) + 1
				var stage_next: Dictionary = chain_def["stages"][int(crisis["stage"])]
				crisis["stage_name_fa"] = str(stage_next.get("name_fa", ""))
				crisis["started_day"] = current_day
				crisis["expires_day"] = current_day + int(stage_next.get("duration_days", 90))
				for effect in stage_next.get("on_enter_effects", []):
					_apply_path_effect(state, effect)
				var stage_msg := "نخ بحران «%s» وارد مرحلهٔ %d/%d «%s» شد" % [
					str(crisis.get("title", "")), int(crisis["stage"]) + 1,
					int(crisis["stage_count"]), str(stage_next.get("name_fa", ""))]
				events.append({"type": "crisis_stage", "title": str(crisis.get("title", "")),
					"stage": int(crisis["stage"]) + 1, "stage_count": int(crisis["stage_count"]),
					"message": stage_msg})
				if stage_next.has("decision"):
					events.append({"type": str(stage_next["decision"]), "title": str(crisis.get("title", "")),
						"severity": int(crisis.get("severity", 1)), "crisis": true,
						"message": "%s — تصمیم فوری لازم است" % stage_msg})
				kept.append(crisis)
				continue
			# ── پایان کامل نخ / بحران تک‌مرحله‌ای ──
			var cooldown := COOLDOWN_DAYS
			if not chain_def.is_empty():
				for effect in chain_def["stages"][chain_def["stages"].size() - 1].get("resolve_effects", []):
					_apply_path_effect(state, effect)
				cooldown = int(chain_def.get("cooldown_days", COOLDOWN_DAYS))
				# اسکار ماندگار پس از نخ (عمق‌بخشی ۵)
				var scar_def: Dictionary = chain_def.get("scar", {})
				if not scar_def.is_empty():
					var scars_now: Array = state["crisis_scars"]
					if scars_now.size() >= MAX_SCARS:
						scars_now.pop_front()
					scars_now.append({
						"id": "%s_scar_%d" % [str(chain_def.get("id", "")), turn],
						"title_fa": str(scar_def.get("title_fa", "اسکار بحران")),
						"effects": scar_def.get("effects", []).duplicate(true),
						"started_day": current_day,
						"expires_day": current_day + int(scar_def.get("duration_months", 12)) * 30
					})
					state["crisis_scars"] = scars_now
					events.append({
						"type": "crisis_scar", "title": str(scar_def.get("title_fa", "")),
						"message": "اثر ماندگار «%s» بر جای ماند — بهبود تدریجی نیازمند زمان است" % str(scar_def.get("title_fa", ""))
					})
			state["crisis_cooldowns"][str(crisis.get("type", ""))] = current_day + cooldown
			var resolved_msg := "بحران «%s» پایان یافت" % str(crisis.get("title", ""))
			if is_chain:
				resolved_msg = "نخ بحران «%s» به پایان رسید و کشور رو به بهبود رفت" % str(crisis.get("title", ""))
			events.append({
				"type": "crisis_resolved",
				"title": str(crisis.get("title", "")),
				"severity": int(crisis.get("severity", 1)),
				"message": resolved_msg
			})
			continue
		# اثر ماهانهٔ مرحلهٔ جاری (برای نخ‌ها: اثر مرحله؛ برای تک‌مرحله‌ای: persist_effects)
		if is_chain and not chain_def.is_empty():
			var stage_now: Dictionary = chain_def["stages"][clampi(int(crisis.get("stage", 0)), 0, chain_def["stages"].size() - 1)]
			for effect in stage_now.get("persist_effects", []):
				_apply_path_effect(state, effect)
		else:
			for effect in crisis.get("persist_effects", []):
				_apply_path_effect(state, effect)
		kept.append(crisis)

	# ۲) ارزیابی دترمینستیک ریسک‌های تازه به ترتیب ثابت تعریف (بحران‌ها سپس نخ‌ها)
	var active_types: Dictionary = {}
	for crisis in kept:
		active_types[str(crisis.get("type", ""))] = true
	var active_count = kept.size()
	for definition in CRISES:
		if active_count >= MAX_ACTIVE_CRISES:
			break
		var crisis_type = str(definition["type"])
		if active_types.has(crisis_type):
			continue
		if float(state["crisis_cooldowns"].get(crisis_type, -1.0)) > current_day:
			continue
		if not _triggered(state, definition):
			continue
		if not Deterministic.chance(float(definition["chance"])):
			continue

		for effect in definition.get("immediate_effects", []):
			_apply_path_effect(state, effect)
		var entry = {
			"instance_id": "%s_%d" % [crisis_type, turn],
			"type": crisis_type,
			"title": str(definition["title"]),
			"severity": int(definition["severity"]),
			"status": "active",
			"started_tick": turn,
			"started_day": current_day,
			"expires_day": current_day + int(definition["duration_days"]),
			"persist_effects": definition.get("persist_effects", []).duplicate(true)
		}
		kept.append(entry)
		active_types[crisis_type] = true
		active_count += 1
		# نوع رویداد عمداً با قالب DecisionManager یکی است تا تصمیم چندگزینه‌ای ساخته شود.
		events.append({
			"type": crisis_type,
			"title": entry["title"],
			"severity": entry["severity"],
			"crisis": true,
			"message": "بحران «%s» آغاز شد؛ تصمیم فوری لازم است" % entry["title"]
		})

	# ۲ب) آغاز نخ‌های بحران (با سقف هم‌زمانِ per-chain و cooldown اختصاصی)
	for chain in chains:
		if active_count >= MAX_ACTIVE_CRISES:
			break
		var chain_type = str(chain.get("id", ""))
		if active_types.has(chain_type):
			continue
		if float(state["crisis_cooldowns"].get(chain_type, -1.0)) > current_day:
			continue
		var instances_now := 0
		for c in kept:
			if str(c.get("type", "")) == chain_type:
				instances_now += 1
		if instances_now >= int(chain.get("max_instances", 1)):
			continue
		if not _triggered(state, chain):
			continue
		if not Deterministic.chance(float(chain.get("chance", 0.1))):
			continue

		var stage_first: Dictionary = chain["stages"][0]
		for effect in stage_first.get("on_enter_effects", []):
			_apply_path_effect(state, effect)
		var chain_entry = {
			"instance_id": "%s_%d" % [chain_type, turn],
			"type": chain_type,
			"title": str(chain.get("title_fa", chain_type)),
			"severity": int(chain.get("severity", 2)),
			"status": "active",
			"started_tick": turn,
			"started_day": current_day,
			"expires_day": current_day + int(stage_first.get("duration_days", 90)),
			"stage": 0,
			"stage_count": chain["stages"].size(),
			"stage_name_fa": str(stage_first.get("name_fa", "")),
			"persist_effects": []
		}
		kept.append(chain_entry)
		active_types[chain_type] = true
		active_count += 1
		events.append({
			"type": str(chain.get("entry_decision", chain_type)),
			"title": chain_entry["title"],
			"severity": chain_entry["severity"],
			"crisis": true,
			"message": "نخ بحران «%s» آغاز شد؛ تصمیم فوری لازم است" % chain_entry["title"]
		})

	state["events_active"] = kept
	return {"state": state, "events": events}

func _triggered(state: Dictionary, definition: Dictionary) -> bool:
	# پشتیبانی از دو شکل: آرایه‌ی قدیمی {trigger_mode در بالا} و ساختار زنجیره {mode/conditions}
	var raw_trigger = definition.get("trigger", [])
	var mode := "all"
	var conditions: Array = []
	if raw_trigger is Dictionary:
		mode = str(raw_trigger.get("mode", "all"))
		conditions = raw_trigger.get("conditions", [])
	else:
		mode = str(definition.get("trigger_mode", "all"))
		conditions = raw_trigger
	if conditions.is_empty():
		return false
	for condition in conditions:
		var value = _read_path(state, str(condition.get("path", "")))
		if not (value is int or value is float):
			if mode == "all":
				return false
			continue
		var hit = float(value) > float(condition["value"]) if str(condition.get("op", ">")) == ">" else float(value) < float(condition["value"])
		if mode == "any" and hit:
			return true
		if mode == "all" and not hit:
			return false
	return mode == "all"

func _read_path(source: Dictionary, path: String):
	var current = source
	for part in path.split("."):
		if not current is Dictionary or not current.has(part):
			return null
		current = current[part]
	return current

# اعمال اثر عددی روی مسیر state با همان قرارداد DecisionManager (add/mul/set + min/max)
func _apply_path_effect(state: Dictionary, effect: Dictionary):
	var parts = str(effect.get("path", "")).split(".")
	var current = state
	for i in range(parts.size() - 1):
		if not current is Dictionary or not current.has(parts[i]):
			return
		current = current[parts[i]]
	var key = parts[-1]
	if not current is Dictionary or not current.has(key):
		return
	if not (current[key] is int or current[key] is float):
		return
	var new_value = float(current[key])
	match str(effect.get("op", "add")):
		"mul": new_value *= float(effect.get("value", 1.0))
		"set": new_value = float(effect.get("value", new_value))
		_: new_value += float(effect.get("value", 0.0))
	if effect.has("min"):
		new_value = max(new_value, float(effect["min"]))
	if effect.has("max"):
		new_value = min(new_value, float(effect["max"]))
	current[key] = new_value
