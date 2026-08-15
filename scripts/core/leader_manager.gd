extends Node
# ────────────────────────────────────────────────────────────────────────────
# رهبر کشور — محبوبیت جهانی، پنهان/آشکار در جنگ، ترور و ضدترور، شورش شهرها،
# و حالت «ژنرال وفادار» پس از ترور رهبر: کودتا در ۷ نوبت، الحاق یا حاکم دست‌نشانده.
#
# state["leader"]:
#   name_fa, alive, popularity_world (0..100), hidden (پنهان در جنگ),
#   mode: "leader" | "general", country_status: "independent"|"annexed"|"puppet",
#   rebellion: { start_turn, deadline_turn, base_province, controlled:[...], total, progress, failed }
# world["leader_deaths"]  = { country: { turn, by, popularity } }
# world["annexations"]    = [ { annexed, by, turn } ]
# world["puppets"]        = [ { puppet, master, turn } ]
# world["rebel_regions"]  = { country: { provinces, turn } }   # شورش پس از ترور رهبر محبوب
# ────────────────────────────────────────────────────────────────────────────

const REBELLION_TURNS := 7
const ANNEX_DISTANCE_DEG := 16.0

# ── تضمین ساختار رهبر در state ──
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("leader"):
		# ── شخصیت‌پردازی رهبر (عمق‌بخشی ۱۲) ──
		# نام و سن تصادفیِ دترمینستیک از نام‌های فارسی؛ هر رهبر یک شخص است
		# نه «رهبر ملی» بی‌نام. ویژگی‌ها با رویدادهای بزرگ کسب می‌شوند.
		var first_names := ["آرش", "بهرام", "کاوه", "داریوش", "فریدون", "گردآفرید",
			"هوشنگ", "ایرج", "تهماسب", "کیان", "رستم", "سپهر", "مهرداد", "نرسی",
			"پرویز", "جمشید", "خشایار", "لهراسب", "مهراب", "نوشین"]
		var last_names := ["میرزایی", "کیانی", "رستمی", "بهرامی", "سپهری", "آذری",
			"جهانبخش", "خسروی", "دلیری", "رادمنش", "سامانی", "شیرازی", "فرزام",
			"کامروا", "مهربان", "نیک‌نام", "همایون", "یگانه"]
		var name_idx := Deterministic.next_int_range(0, first_names.size() - 1)
		var family_idx := Deterministic.next_int_range(0, last_names.size() - 1)
		var leader_age := Deterministic.next_int_range(48, 68)
		state["leader"] = {
			"name_fa": "%s %s" % [first_names[name_idx], last_names[family_idx]],
			"age": leader_age,
			"alive": true, "popularity_world": 50.0,
			"hidden": false, "mode": "leader", "country_status": "independent",
			"rebellion": {}, "traits": []
		}
	var world: Dictionary = state.get("world", {})
	if not world.has("leader_deaths"):
		world["leader_deaths"] = {}
	if not world.has("annexations"):
		world["annexations"] = []
	if not world.has("puppets"):
		world["puppets"] = []
	if not world.has("rebel_regions"):
		world["rebel_regions"] = {}
	state["world"] = world
	return state

# ────────────────────────────────────────────────────────────────────────────
# شبیه‌سازی ماهانه رهبر: محبوبیت جهانی از اعمال این نوبت + شورش‌ها + کودتا
# ────────────────────────────────────────────────────────────────────────────
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var leader: Dictionary = state["leader"]
	var player_id := str(state.get("world", {}).get("player_country", WorldManager.default_country))

	# ── حالت ژنرال: پیشروی کودتا یا حل شکست ──
	if str(leader.get("mode", "leader")) == "general":
		var rebellion: Dictionary = leader.get("rebellion", {})
		if not bool(rebellion.get("failed", false)):
			if turn > int(rebellion.get("deadline_turn", turn)):
				var fail_result = _resolve_rebellion_failure(state, turn)
				state = fail_result.state
				events.append_array(fail_result.events)
			else:
				var adv = _advance_rebellion(state, turn)
				state = adv.state
				events.append_array(adv.events)
		return {"state": state, "events": events}

	# ── ویژگی‌های رهبر: کسب از رویدادهای بزرگ + اثر ماهانه ──
	_acquire_traits_from_history(state, turn)
	_apply_trait_effects(state)

	# ── محبوبیت جهانی: اثر اعمال رهبر در جهان ──
	var pop: float = clampf(float(leader.get("popularity_world", 50.0)), 0.0, 100.0)
	var world: Dictionary = state.get("world", {})
	var relations: Dictionary = state.get("diplomacy", {}).get("relations", {})
	var wars: Dictionary = world.get("wars", {})
	var war_history: Array = world.get("war_history", [])
	var trade_count: int = world.get("trade_agreements", []).size()
	var sanctions: int = state.get("diplomacy", {}).get("sanctions", []).size()

	# شروع جنگ توسط بازیکن در این نوبت → سقوط محبوبیت جهانی
	for war_target in wars.keys():
		if int(wars[war_target].get("started_tick", -1)) == turn:
			pop -= 6.0
			events.append({"type": "world_opinion", "message": "اعلام جنگ، محبوبیت جهانی رهبر را ۶ واحد کاهش داد"})
			break
	# پایان جنگ در این نوبت → بازگشت محبوبیت
	for entry in war_history:
		if int(entry.get("ended_turn", -1)) == turn and bool(entry.get("peace", false)):
			pop += 4.0
	# تحریم‌های اقتصادی → کاهش تدریجی
	pop -= float(sanctions) * 0.4
	# توافق‌های تجاری → افزایش
	pop += float(trade_count) * 0.12
	# اقتصاد رو به رشد → محبوبیت
	if float(state.get("economy", {}).get("growth_rate", 0.0)) > 0.03:
		pop += 1.0
	# جنگ طولانی → فرسایش
	if wars.size() > 0:
		pop -= 1.0
	# رهبر پنهان: از مردم و جهان دور است
	if bool(leader.get("hidden", false)):
		pop -= 1.2
	# بازگشت طبیعی به نقطه تعادل
	pop += (50.0 - pop) * 0.01
	leader["popularity_world"] = clampf(pop, 0.0, 100.0)

	# ── شورش‌های پس از ترور رهبران محبوب جهان ──
	var rebel_regions: Dictionary = world.get("rebel_regions", {})
	var done_rebels: Array = []
	for rcid in rebel_regions.keys():
		var rebel: Dictionary = rebel_regions[rcid]
		var age: int = turn - int(rebel.get("turn", turn))
		if age >= 6:
			done_rebels.append(rcid)
			continue
		# شورش اقتصاد کشور را می‌فرساید و ثبات داخلی را می‌شکند
		if world.get("countries", {}).has(rcid):
			var runtime: Dictionary = world["countries"][rcid]
			runtime["gdp"] = max(1.0, float(runtime.get("gdp", 1.0)) * 0.985)
			runtime["stability"] = clampf(float(runtime.get("stability", 60.0)) - 1.5, 5.0, 100.0)
			world["countries"][rcid] = runtime
		if age == 1:
			events.append({"type": "rebellion_news", "message": "شورش‌های مردمی در %s پس از ترور رهبر محبوب همچنان ادامه دارد" % WorldManager.get_country_name(rcid)})
	for done in done_rebels:
		rebel_regions.erase(done)
	world["rebel_regions"] = rebel_regions
	state["world"] = world
	state["leader"] = leader
	return {"state": state, "events": events}

# ── تغییر وضعیت پنهان/آشکار رهبر در جنگ (هرکدام عواقب واقعی) ──
# ── انتخاب نام رهبر توسط بازیکن (عمق‌بخشی ۱۳) ──
# بازیکن می‌تواند نام رهبر کشورش را خودش انتخاب کند (نه فقط تصادفی).
func set_leader_name(state: Dictionary, name: String) -> Dictionary:
	state = ensure(state)
	var clean := name.strip_edges()
	if clean.length() < 2 or clean.length() > 30:
		return {"state": state, "success": false, "reason": "نام باید بین ۲ تا ۳۰ نویسه باشد"}
	# جلوگیری از نویسه‌های کنترلی
	var safe := ""
	for ch in clean:
		if ch.unicode_at(0) >= 32:
			safe += ch
	state["leader"]["name_fa"] = safe
	return {"state": state, "success": true, "events": [{
		"type": "leader_name_set", "message": "رهبر کشور: «%s»" % safe
	}]}

func set_hidden(state: Dictionary, hidden: bool, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var leader: Dictionary = state["leader"]
	if bool(leader.get("hidden", false)) == hidden:
		return {"state": state, "events": events}
	leader["hidden"] = hidden
	if hidden:
		# پنهان: امنیت بیشتر ولی روحیه، رضایت و محبوبیت آسیب می‌بیند
		state.get("population", {})["happiness"] = clampf(float(state.get("population", {}).get("happiness", 0.6)) - 0.015, 0.0, 1.0)
		state.get("military", {})["morale"] = clampf(float(state.get("military", {}).get("morale", 0.7)) - 0.02, 0.0, 1.0)
		leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) - 2.0, 0.0, 100.0)
		events.append({"type": "leader_hidden", "message": "رهبر به مکان امن منتقل شد و فعالیت‌هایش پنهان شد؛ روحیه مردم و ارتش اندکی آسیب دید"})
	else:
		state.get("population", {})["happiness"] = clampf(float(state.get("population", {}).get("happiness", 0.6)) + 0.01, 0.0, 1.0)
		state.get("military", {})["morale"] = clampf(float(state.get("military", {}).get("morale", 0.7)) + 0.015, 0.0, 1.0)
		leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) + 1.5, 0.0, 100.0)
		events.append({"type": "leader_visible", "message": "رهبر آشکارا در برابر مردم ظاهر شد؛ روحیه ملی بالا رفت اما او در معرض خطر بیشتری است"})
	state["leader"] = leader
	return {"state": state, "events": events}

# ────────────────────────────────────────────────────────────────────────────
# ترور — شرط فناوری‌ها و توازن حمله/دفاع
# ────────────────────────────────────────────────────────────────────────────
func _branch_level(state: Dictionary, branch: String) -> float:
	return float(state.get("technology", {}).get("branch_levels", {}).get(branch, 0.0))

func _enemy_defense_level(state: Dictionary, target_id: String) -> float:
	# دفاع ضدترور هدف: فناوری‌های ضداطلاعات + رهگیری
	var world: Dictionary = state.get("world", {})
	var player_id := str(world.get("player_country", WorldManager.default_country))
	var def_level := 0.0
	if target_id == player_id:
		def_level = _branch_level(state, "دیجیتال") + _branch_level(state, "نظامی") * 0.5
		if state.get("technology", {}).get("unlocked", []).has("counter_intel_network"):
			def_level += 8.0
	else:
		# NPC: از سطح فناوری کلی کشور
		var runtime: Dictionary = world.get("countries", {}).get(target_id, {})
		def_level = float(runtime.get("tech_level", 0.35)) * 26.0
		if _npc_has_tech(state, target_id, "counter_intel"):
			def_level += 8.0
	# پنهان بودن رهبر: پیدا کردن او سخت‌تر است
	if bool(state.get("leader", {}).get("hidden", false)) and target_id == player_id:
		def_level += 10.0
	# اگر مهاجم فناوری «رهگیری رهبران» داشته باشد، پنهان‌بودن بی‌اثر است
	elif _npc_has_tech(state, target_id, "tracking"):
		pass
	return def_level

func _npc_has_tech(state: Dictionary, country_id: String, kind: String) -> bool:
	# ساده‌سازی: کشورهای با فناوری بالا فناوری‌های دفاعی دارند
	var runtime: Dictionary = state.get("world", {}).get("countries", {}).get(country_id, {})
	var tech := float(runtime.get("tech_level", 0.35))
	if kind == "counter_intel":
		return tech >= 0.72
	if kind == "tracking":
		return tech >= 0.80
	return false

# شانس موفقیت ترور (برای نمایش در UI و اجرا)
func assassination_chance(state: Dictionary, target_id: String) -> float:
	state = ensure(state)
	if not _can_assassinate(state, target_id).valid:
		return 0.0
	var world: Dictionary = state.get("world", {})
	var player_id := str(world.get("player_country", WorldManager.default_country))
	if target_id == player_id:
		return 0.0
	var off := (_branch_level(state, "نظامی") + _branch_level(state, "دیجیتال")) * 0.5
	var def := _enemy_defense_level(state, target_id)
	var hidden_penalty := 0.0
	if bool(state.get("leader", {}).get("hidden", false)) and target_id == player_id:
		hidden_penalty = -0.14
	var p := 0.32 + (off - def) * 0.028 + hidden_penalty
	return clampf(p, 0.04, 0.82)

func _can_assassinate(state: Dictionary, target_id: String) -> Dictionary:
	state = ensure(state)
	var world: Dictionary = state.get("world", {})
	var player_id := str(world.get("player_country", WorldManager.default_country))
	if target_id == player_id:
		return {"valid": false, "reason": "نمی‌توان رهبر کشور خود را ترور کرد"}
	if not state.get("technology", {}).get("unlocked", []).has("assassination_ops"):
		return {"valid": false, "reason": "نیازمند فناوری «عملیات ترور هدفمند» است"}
	var relations: Dictionary = state.get("diplomacy", {}).get("relations", {})
	var at_war: bool = world.get("wars", {}).has(target_id)
	var rel: float = float(relations.get(target_id, 50.0))
	if not at_war and rel > 35.0:
		return {"valid": false, "reason": "فقط علیه دشمنان (جنگ یا روابط خصمانه) می‌توان ترور کرد"}
	return {"valid": true, "reason": ""}

# اجرای ترور توسط بازیکن
func attempt_assassination(state: Dictionary, target_id: String, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var check := _can_assassinate(state, target_id)
	if not check.valid:
		return {"state": state, "events": events, "success": false, "reason": check.reason}
	var p := assassination_chance(state, target_id)
	var success := Deterministic.chance(p)
	var world: Dictionary = state.get("world", {})
	var player_id := str(world.get("player_country", WorldManager.default_country))
	if success:
		var death_result = _resolve_death(state, target_id, player_id, turn, "assassination")
		state = death_result.state
		events.append_array(death_result.events)
		events.append({"type": "assassination_success",
			"message": "عملیات ترور موفق بود؛ رهبر %s ترور شد" % WorldManager.get_country_name(target_id)})
		# محبوبیت جهانی ترورکننده سقوط می‌کند (جهان ترور را محکوم می‌کند)
		var leader: Dictionary = state["leader"]
		leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) - 9.0, 0.0, 100.0)
		var a_traits: Array = leader.get("traits", [])
		if not a_traits.has("دست‌پنهان") and a_traits.size() < 3:
			a_traits.append("دست‌پنهان")
			leader["traits"] = a_traits
		state["leader"] = leader
	else:
		events.append({"type": "assassination_failed",
			"message": "ترور رهبر %s نافرجام ماند؛ ضداطلاعات او نقشه را خنثی کرد" % WorldManager.get_country_name(target_id)})
		var discovered := Deterministic.chance(0.7)
		if discovered:
			var relations: Dictionary = state.get("diplomacy", {}).get("relations", {})
			if relations.has(target_id):
				relations[target_id] = max(0.0, float(relations[target_id]) - 25.0)
			state["diplomacy"]["relations"] = relations
			events.append({"type": "assassination_exposed",
				"message": "دست داشتن شما در ترور رهبر %s فاش شد؛ روابط جهانی به شدت آسیب دید" % WorldManager.get_country_name(target_id)})
			# اگر رابطه خیلی بد شد، دشمن اعلام جنگ می‌کند
			if float(relations.get(target_id, 50.0)) <= 18.0 and not world.get("wars", {}).has(target_id) \
					and world.get("countries", {}).has(target_id):
				world["wars"][target_id] = {"target": target_id, "started_tick": turn,
						"progress": 0.0, "player_losses": 0, "enemy_losses": 0}
				events.append({"type": "npc_war_started", "a": player_id, "b": target_id,
					"message": "%s در واکنش به افشای ترور اعلام جنگ کرد" % WorldManager.get_country_name(target_id)})
			state["world"] = world
	return {"state": state, "events": events, "success": success}

# تلاش ماهانه دشمنان برای ترور رهبر بازیکن
func npc_assassination_attempt(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var leader: Dictionary = state["leader"]
	if not bool(leader.get("alive", true)) or str(leader.get("mode", "leader")) != "leader":
		return {"state": state, "events": events}
	var world: Dictionary = state.get("world", {})
	var player_id := str(world.get("player_country", WorldManager.default_country))
	var relations: Dictionary = state.get("diplomacy", {}).get("relations", {})
	for enemy in world.get("wars", {}).keys():
		if enemy == player_id:
			continue
		var runtime: Dictionary = world.get("countries", {}).get(enemy, {})
		var tech := float(runtime.get("tech_level", 0.35))
		if tech < 0.70:
			continue
		# دشمنِ فناوری‌محور هر نوبت شانس محدودی برای ترور دارد
		if not Deterministic.chance(0.10):
			continue
		var def := _enemy_defense_level(state, player_id)
		var off := tech * 30.0
		var hidden_bonus := 8.0 if bool(leader.get("hidden", false)) else -3.0
		var p := clampf(0.30 + (off - def + hidden_bonus) * 0.02, 0.05, 0.70)
		if Deterministic.chance(p):
			var death_result = _resolve_death(state, player_id, enemy, turn, "enemy_assassination")
			state = death_result.state
			events.append_array(death_result.events)
			events.append({"type": "leader_assassinated",
				"message": "رهبر شما توسط %s ترور شد!" % WorldManager.get_country_name(enemy)})
			return {"state": state, "events": events}
		else:
			# ناموفق: کشف تلاش → رابطه بدتر
			if relations.has(enemy):
				relations[enemy] = max(0.0, float(relations[enemy]) - 6.0)
			state["diplomacy"]["relations"] = relations
			events.append({"type": "assassination_foiled",
				"message": "طرح ترور رهبر شما توسط %s ناکام ماند و خنثی شد" % WorldManager.get_country_name(enemy)})
			break
	return {"state": state, "events": events}

# ────────────────────────────────────────────────────────────────────────────
# مرگ رهبر: شورش شهرها اگر محبوب بود + ورود به حالت ژنرال وفادار (برای بازیکن)
# ────────────────────────────────────────────────────────────────────────────
func _resolve_death(state: Dictionary, country_id: String, killer_id: String, turn: int, method: String) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var world: Dictionary = state["world"]
	var player_id := str(world.get("player_country", WorldManager.default_country))
	var deaths: Dictionary = world.get("leader_deaths", {})
	var popularity := 50.0
	var leader: Dictionary = state.get("leader", {})
	if country_id == player_id:
		popularity = float(leader.get("popularity_world", 50.0))
		leader["alive"] = false
		state["leader"] = leader
	else:
		popularity = float(leader.get("popularity_world", 50.0)) * 0.5 + 40.0
	deaths[country_id] = {"turn": turn, "by": killer_id, "popularity": popularity, "method": method}
	world["leader_deaths"] = deaths

	# شورش شهرها اگر رهبر در جهان محبوب بود
	if popularity >= 55.0:
		var provinces: int = 2 + int(popularity / 22.0)
		var rebel_regions: Dictionary = world.get("rebel_regions", {})
		rebel_regions[country_id] = {"provinces": provinces, "turn": turn}
		world["rebel_regions"] = rebel_regions
		events.append({"type": "rebellion_started",
			"message": "ترور رهبر محبوب %s خشم عمومی را برانگیخت؛ %s شهر به شورش پیوستند" % [
				WorldManager.get_country_name(country_id), PersianFormatter.to_persian_digits(str(provinces))]})
	state["world"] = world

	# بازیکن ترور شد → نقش «ژنرال وفادار» آغاز می‌شود (بازی ادامه دارد)
	if country_id == player_id:
		var rebellion_result = _start_rebellion(state, turn)
		state = rebellion_result.state
		events.append_array(rebellion_result.events)
	return {"state": state, "events": events}

# ────────────────────────────────────────────────────────────────────────────
# حالت ژنرال وفادار: کودتا در بهترین استان + تصاحب کشور در ۷ نوبت
# ────────────────────────────────────────────────────────────────────────────
func _country_units(country_id: String) -> Array:
	var maps: Dictionary = CountryGeographyManager.countries
	if maps.has(country_id):
		return maps[country_id].get("units", [])
	return []

func _best_province(country_id: String) -> String:
	var units := _country_units(country_id)
	var best := ""
	var best_weight := -1.0
	for unit in units:
		if bool(unit.get("capital", false)):
			return str(unit.get("id", ""))
		var weight := float(unit.get("area_weight", 0.0))
		if weight > best_weight:
			best_weight = weight
			best = str(unit.get("id", ""))
	return best

func _start_rebellion(state: Dictionary, turn: int) -> Dictionary:
	var events: Array = []
	var leader: Dictionary = state["leader"]
	leader["mode"] = "general"
	leader["country_status"] = "independent"
	var player_id := str(state.get("world", {}).get("player_country", WorldManager.default_country))
	var units := _country_units(player_id)
	var base := _best_province(player_id)
	# تنها بخشی از ارتش به ژنرال وفادار می‌پیوندد:
	#  - رضایت مردم از رهبر قبلی (happiness)
	#  - محبوبیت جهانی رهبر قبلی: ژنرالِ رهبرِ محبوب، ارتش و مردم بیشتری را با خود
	#    همراه می‌کند و کودتا سریع‌تر پیش می‌رود؛ رهبرِ منفور، پشتیبانی نمی‌گیرد.
	var happiness := clampf(float(state.get("population", {}).get("happiness", 0.6)), 0.0, 1.0)
	var world_popularity := clampf(float(leader.get("popularity_world", 50.0)), 0.0, 100.0)
	var loyal_factor := clampf(0.30 + happiness * 0.55 + world_popularity / 100.0 * 0.45, 0.30, 0.95)
	var rebellion := {
		"start_turn": turn,
		"deadline_turn": turn + REBELLION_TURNS,
		"base_province": base,
		"controlled": [base],
		"total": max(1, units.size()),
		"progress": 1,
		"failed": false,
		"loyal_power": float(state.get("military", {}).get("power", 50.0)) * loyal_factor,
		"popularity": world_popularity
	}
	leader["rebellion"] = rebellion
	state["leader"] = leader
	events.append({"type": "rebellion_started",
		"message": "رهبر ترور شد اما کشور با ژنرال وفادار ادامه می‌یابد؛ کودتا از استان پایگاه آغاز شد — %s نوبت برای تصاحب کامل کشور" % PersianFormatter.to_persian_digits(str(REBELLION_TURNS))})
	return {"state": state, "events": events}

func _advance_rebellion(state: Dictionary, turn: int) -> Dictionary:
	var events: Array = []
	var leader: Dictionary = state["leader"]
	var rebellion: Dictionary = leader.get("rebellion", {})
	var controlled: Array = rebellion.get("controlled", [])
	var total := int(rebellion.get("total", 1))
	var remaining: int = max(0, total - controlled.size())
	var turns_left: int = max(1, int(rebellion.get("deadline_turn", turn)) - turn)
	if remaining <= 0:
		return {"state": state, "events": events}
	# پیشروی: هرچه فرصت کمتر، تصاحب سریع‌تر (فشار زمانی کودتا)
	# نیروی وفادار به ژنرال (ثبت‌شده هنگام کودتا) سرعت را تعیین می‌کند؛
	# ارتش ضعیف/وفاداری کم نمی‌تواند در مهلت ۷ نوبت کشور را بگیرد (شکست → الحاق/دست‌نشانده)
	var mil_factor := clampf(float(rebellion.get("loyal_power", 30.0)) / 45.0, 0.30, 1.15)
	var gains: int = max(1, int(ceil(float(remaining) / float(turns_left) * mil_factor)))
	gains = min(gains, remaining)
	for i in range(gains):
		controlled.append("prov_" + str(controlled.size()))
	rebellion["controlled"] = controlled
	rebellion["progress"] = controlled.size()
	leader["rebellion"] = rebellion
	state["leader"] = leader
	if controlled.size() >= total:
		# پیروزی کودتا: ژنرال رهبر جدید کشور می‌شود
		leader["mode"] = "leader"
		leader["alive"] = true
		leader["name_fa"] = "ژنرال پیروز"
		leader["rebellion"] = {}
		var coup_traits: Array = leader.get("traits", [])
		if not coup_traits.has("ژنرال-رهبر") and coup_traits.size() < 3:
			coup_traits.append("ژنرال-رهبر")
			leader["traits"] = coup_traits
		leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) + 8.0, 0.0, 100.0)
		state["leader"] = leader
		state.get("population", {})["happiness"] = clampf(float(state.get("population", {}).get("happiness", 0.6)) + 0.05, 0.0, 1.0)
		state.get("politics", {})["stability"] = clampf(float(state.get("politics", {}).get("stability", 0.6)) + 0.08, 0.0, 1.0)
		events.append({"type": "coup_victory",
			"message": "کودتای ژنرال وفادار پیروز شد؛ سراسر کشور تحت فرمان اوست و او رهبر جدید شد"})
	else:
		events.append({"type": "coup_progress",
			"message": "ژنرال وفادار %s استان دیگر را تصرف کرد (%s از %s)" % [
				PersianFormatter.to_persian_digits(str(gains)),
				PersianFormatter.to_persian_digits(str(controlled.size())),
				PersianFormatter.to_persian_digits(str(total))]})
	return {"state": state, "events": events}

func _resolve_rebellion_failure(state: Dictionary, turn: int) -> Dictionary:
	var events: Array = []
	var leader: Dictionary = state["leader"]
	var rebellion: Dictionary = leader.get("rebellion", {})
	rebellion["failed"] = true
	leader["rebellion"] = rebellion
	state["leader"] = leader
	var world: Dictionary = state.get("world", {})
	var player_id := str(world.get("player_country", WorldManager.default_country))
	# کشورِ برنده: کسی که رهبر را ترور کرد (یا قوی‌ترین دشمن در جنگ)
	var winner := ""
	var deaths: Dictionary = world.get("leader_deaths", {})
	if deaths.has(player_id):
		winner = str(deaths[player_id].get("by", ""))
	if winner == "" or not world.get("countries", {}).has(winner):
		winner = _strongest_enemy(state, player_id)
	if winner == "":
		# بدون برنده مشخص: کشور به چندپارگی داخلی می‌افتد
		state.get("politics", {})["stability"] = clampf(float(state.get("politics", {}).get("stability", 0.6)) - 0.15, 0.0, 1.0)
		events.append({"type": "coup_failed", "message": "کودتا نافرجام ماند و کشور در هرج‌ومرج داخلی فرو رفت"})
		return {"state": state, "events": events}
	# هم‌مرز بودن: الحاق کامل خاک + توانایی‌ها به برنده
	if _is_neighbor(state, player_id, winner):
		world["annexations"].append({"annexed": player_id, "by": winner, "turn": turn})
		leader["country_status"] = "annexed"
		var loser_runtime: Dictionary = world["countries"].get(player_id, {})
		var winner_runtime: Dictionary = world["countries"].get(winner, {})
		winner_runtime["gdp"] = float(winner_runtime.get("gdp", 1.0)) + float(loser_runtime.get("gdp", 0.0)) * 0.6
		winner_runtime["population"] = float(winner_runtime.get("population", 1.0)) + float(loser_runtime.get("population", 0.0)) * 0.7
		winner_runtime["military_power"] = clampf(float(winner_runtime.get("military_power", 50.0)) + float(loser_runtime.get("military_power", 50.0)) * 0.4, 8.0, 150.0)
		winner_runtime["tech_level"] = max(float(winner_runtime.get("tech_level", 0.3)), float(loser_runtime.get("tech_level", 0.3)))
		world["countries"][winner] = winner_runtime
		# کشور بازیکن به برنده ملحق می‌شود
		loser_runtime["annexed_by"] = winner
		world["countries"][player_id] = loser_runtime
		events.append({"type": "country_annexed",
			"message": "کودتا نافرجام ماند؛ %s که هم‌مرز بود، سراسر کشور را ضمیمه خاک خود کرد و توانایی‌های آن به او منتقل شد" % WorldManager.get_country_name(winner)})
	else:
		# بدون مرز مشترک: حاکم دست‌نشانده
		world["puppets"].append({"puppet": player_id, "master": winner, "turn": turn})
		leader["country_status"] = "puppet"
		var puppet_runtime: Dictionary = world["countries"].get(player_id, {})
		puppet_runtime["puppet_master"] = winner
		world["countries"][player_id] = puppet_runtime
		events.append({"type": "puppet_installed",
			"message": "کودتا نافرجام ماند؛ %s که مرز مشترک نداشت، حاکم دست‌نشانده در کشور شما گماشت و کشور عملاً زیر سلطه اوست" % WorldManager.get_country_name(winner)})
	state["world"] = world
	return {"state": state, "events": events}

func _strongest_enemy(state: Dictionary, player_id: String) -> String:
	var world: Dictionary = state.get("world", {})
	var best := ""
	var best_power := -1.0
	for enemy in world.get("wars", {}).keys():
		if enemy == player_id:
			continue
		var power := float(world.get("countries", {}).get(enemy, {}).get("military_power", 0.0))
		if power > best_power:
			best_power = power
			best = enemy
	return best

# هم‌مرز تقریبی: فاصله مراکز دو کشور کمتر از آستانه (داده دقیق مرز مشترک نیست)
func _is_neighbor(state: Dictionary, a: String, b: String) -> bool:
	var profile_a: Dictionary = WorldManager.get_country(a)
	var profile_b: Dictionary = WorldManager.get_country(b)
	var lat_a := deg_to_rad(float(profile_a.get("lat", 0.0)))
	var lon_a := deg_to_rad(float(profile_a.get("lon", 0.0)))
	var lat_b := deg_to_rad(float(profile_b.get("lat", 0.0)))
	var lon_b := deg_to_rad(float(profile_b.get("lon", 0.0)))
	var dlat := lat_b - lat_a
	var dlon := lon_b - lon_a
	var h: float = pow(sin(dlat * 0.5), 2.0) + cos(lat_a) * cos(lat_b) * pow(sin(dlon * 0.5), 2.0)
	var dist_deg: float = rad_to_deg(2.0 * atan2(sqrt(h), sqrt(max(0.0, 1.0 - h))))
	return dist_deg <= ANNEX_DISTANCE_DEG


# ────────────────────────────────────────────────────────────────
# ویژگی‌های رهبر: شخصیت رهبر از کنش‌های او شکل می‌گیرد (حداکثر ۳ ویژگی)
# ────────────────────────────────────────────────────────────────
const TRAIT_INFO := {
	"فاتح": {"name": "فاتح", "desc": "پیروزی در جنگ؛ ارتش پرقدرت‌تر و مردم امیدوارتر"},
	"شکست‌خورده": {"name": "شکست‌خورده", "desc": "شکست نظامی؛ ثبات و اعتبار رهبر آسیب دیده"},
	"جنگ‌طلب": {"name": "جنگ‌طلب", "desc": "آغاز جنگ؛ ارتش تقویت می‌شود اما جهان محبوبیت را کم می‌کند"},
	"صلح‌جو": {"name": "صلح‌جو", "desc": "پیمان صلح؛ شادی مردم و تجارت بهبود می‌یابد"},
	"پیشرو": {"name": "پیشرو", "desc": "عصر طلایی فناوری؛ پژوهش شتاب می‌گیرد"},
	"ژنرال-رهبر": {"name": "ژنرال-رهبر", "desc": "پیروزی کودتا؛ ثبات و اقتدار نظامی"},
	"دست‌پنهان": {"name": "دست‌پنهان", "desc": "ترور موفق؛ توان اطلاعاتی بالا اما اعتبار جهانی کمتر"}
}

func _add_trait(state: Dictionary, trait_id: String, turn: int) -> Dictionary:
	var leader: Dictionary = state["leader"]
	var traits: Array = leader.get("traits", [])
	if not traits.has(trait_id) and traits.size() < 3:
		traits.append(trait_id)
		leader["traits"] = traits
		state["leader"] = leader
		var info: Dictionary = TRAIT_INFO.get(trait_id, {})
		EventLog.log_event("leader_trait", {"message": "رهبر ویژگی «%s» را به دست آورد" % info.get("name", trait_id), "trait": trait_id}, turn, state.get("version", 0))
	return state

func _acquire_traits_from_history(state: Dictionary, turn: int):
	var world: Dictionary = state.get("world", {})
	var player_id := str(world.get("player_country", WorldManager.default_country))
	var leader: Dictionary = state["leader"]
	if str(leader.get("mode", "leader")) != "leader":
		return
	var traits: Array = leader.get("traits", [])
	# رویدادهای مصرف‌شده تا هر رویداد فقط یک‌بار ویژگی دهد
	var consumed: Array = leader.get("trait_history_consumed", [])
	# پیروزی/شکست/صلح (ended_tick = روز شبیه‌سازی؛ برای هر ورودی تازه یک‌بار بررسی می‌شود)
	for entry in world.get("war_history", []):
		var entry_key := str(entry.get("outcome", "")) + ":" + str(entry.get("target", "")) + ":" + str(entry.get("ended_tick", 0))
		if consumed.has(entry_key):
			continue
		consumed.append(entry_key)
		leader["trait_history_consumed"] = consumed
		if str(entry.get("outcome", "")) == "victory":
			if not traits.has("فاتح"):
				state = _add_trait(state, "فاتح", turn)
				return
		elif str(entry.get("outcome", "")) == "defeat":
			if not traits.has("شکست‌خورده"):
				state = _add_trait(state, "شکست‌خورده", turn)
				return
		elif str(entry.get("outcome", "")) == "peace":
			if not traits.has("صلح‌جو"):
				state = _add_trait(state, "صلح‌جو", turn)
				return
	# جنگ تازه آغازشده (started_tick = روز شبیه‌سازی؛ از روی مصرف‌شده‌ها)
	for target in world.get("wars", {}).keys():
		var war_start_key := "start:" + str(target) + ":" + str(world["wars"][target].get("started_tick", 0))
		if consumed.has(war_start_key):
			continue
		consumed.append(war_start_key)
		leader["trait_history_consumed"] = consumed
		if not traits.has("جنگ‌طلب"):
			state = _add_trait(state, "جنگ‌طلب", turn)
			return
	# عصر طلایی
	var victory: Dictionary = state.get("victory", {})
	if bool(victory.get("achieved", false)):
		if not consumed.has("golden_age") and not traits.has("پیشرو"):
			consumed.append("golden_age")
			leader["trait_history_consumed"] = consumed
			state = _add_trait(state, "پیشرو", turn)
			return

func _apply_trait_effects(state: Dictionary):
	var leader: Dictionary = state["leader"]
	var traits: Array = leader.get("traits", [])
	if traits.is_empty():
		return
	var mil: Dictionary = state.get("military", {})
	var pop: Dictionary = state.get("population", {})
	var pol: Dictionary = state.get("politics", {})
	var tech: Dictionary = state.get("technology", {})
	var intel: Dictionary = state.get("intelligence", {})
	for trait_id in traits:
		match str(trait_id):
			"فاتح":
				mil["power"] = float(mil.get("power", 50.0)) * 1.01
				pol["stability"] = clampf(float(pol.get("stability", 0.6)) + 0.004, 0.05, 1.0)
				leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) + 0.4, 0.0, 100.0)
			"شکست‌خورده":
				pol["stability"] = clampf(float(pol.get("stability", 0.6)) - 0.004, 0.05, 1.0)
				pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) - 0.003, 0.05, 1.0)
			"جنگ‌طلب":
				mil["power"] = float(mil.get("power", 50.0)) * 1.006
				leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) - 0.4, 0.0, 100.0)
			"صلح‌جو":
				pop["happiness"] = clampf(float(pop.get("happiness", 0.6)) + 0.003, 0.05, 1.0)
				# ضربهٔ مستقیم سطح صادرات حذف شد (بازرسی کلید یتیم ۱۴۰۵ — مالکیت یکتای
				# trade). اثر واقع‌گرایانهٔ رهبر صلح‌جو: بهبود روابط با سردترین شریک.
				var leader_rels: Dictionary = state.get("diplomacy", {}).get("relations", {})
				if not leader_rels.is_empty():
					var weakest: String = ""
					var weakest_val: float = 101.0
					for cid in leader_rels.keys():
						var rv: float = float(leader_rels[cid])
						if rv < weakest_val:
							weakest_val = rv
							weakest = str(cid)
					if weakest != "":
						leader_rels[weakest] = clampf(weakest_val + 0.5, 0.0, 100.0)
			"پیشرو":
				tech["research_rate"] = float(tech.get("research_rate", 20.0)) * 1.02
			"ژنرال-رهبر":
				pol["stability"] = clampf(float(pol.get("stability", 0.6)) + 0.006, 0.05, 1.0)
				mil["power"] = float(mil.get("power", 50.0)) * 1.008
			"دست‌پنهان":
				intel["power"] = clampf(float(intel.get("power", 50.0)) + 1.2, 0.0, 100.0)
				leader["popularity_world"] = clampf(float(leader.get("popularity_world", 50.0)) - 0.3, 0.0, 100.0)
	state["leader"] = leader
	state["military"] = mil
	state["population"] = pop
	state["politics"] = pol
	state["technology"] = tech
	state["intelligence"] = intel
