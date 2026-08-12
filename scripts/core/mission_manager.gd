extends Node
# ============================================================
# 🎯 مدیر مأموریت‌ها (الهام از World Empire)
# مأموریت‌های ماهانه با هدف مشخص و پاداش (اعتبار بین‌المللی + سرمایه سیاسی).
# پیشرفت هر مأموریت از وضعیت زنده بازی خوانده می‌شود؛ دترمینستیک و بدون تداخل.
# ============================================================

const MISSION_POOL = [
	{"id": "gdp_target", "title": "رشد اقتصادی", "desc": "GDP سالانه به هدف تعیین‌شده برسد", "icon": "📈"},
	{"id": "law_enact", "title": "تصویب قانون", "desc": "یک قانون جدید تصویب کنید", "icon": "⚖️"},
	{"id": "build_road", "title": "ساخت جاده", "desc": "یک جاده یا راه‌آهن بسازید", "icon": "🛣️"},
	{"id": "win_war", "title": "پیروزی در جنگ", "desc": "در یک جنگ پیروز شوید", "icon": "🏆"},
	{"id": "tech_research", "title": "پیشرفت فناوری", "desc": "یک فناوری جدید پژوهش کنید", "icon": "🔬"},
	{"id": "improve_happiness", "title": "شادی مردم", "desc": "شادی مردم را بالا ببرید", "icon": "😊"},
	{"id": "trade_agreement", "title": "گسترش تجارت", "desc": "یک توافق تجاری جدید امضا کنید", "icon": "📦"},
	{"id": "national_project", "title": "پروژه ملی", "desc": "یک پروژه ملی را آغاز کنید", "icon": "🏗️"},
	{"id": "cabinet_stable", "title": "کابینه باثبات", "desc": "انسجام کابینه را بالا نگه دارید", "icon": "👔"},
	{"id": "military_power", "title": "قدرت نظامی", "desc": "قدرت نظامی را افزایش دهید", "icon": "🛡️"},
]

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	var missions: Array = state.get("missions", [])
	var clock: Dictionary = state.get("clock", {})
	var month: int = int(clock.get("month", 1))
	var year: int = int(clock.get("year", 2027))
	var month_key: String = "%d-%d" % [year, month]

	# مأموریت‌های ماه جدید
	if missions.is_empty() or str(missions[0].get("month_key", "")) != month_key:
		var new_missions: Array = []
		var picked: Array = []
		var seed_val = int(state.get("seed", 12345)) + turn
		for mi in range(4):
			var idx = (seed_val + mi * 37) % MISSION_POOL.size()
			if idx not in picked:
				picked.append(idx)
		for idx in picked:
			var defn: Dictionary = MISSION_POOL[idx]
			new_missions.append({
				"id": defn["id"], "title": defn["title"], "desc": defn["desc"], "icon": defn["icon"],
				"month_key": month_key, "progress": 0.0, "target": 1.0, "done": false, "claimed": false,
				"reward_prestige": 8 + (idx % 3) * 3, "reward_capital": 0.15 + (idx % 3) * 0.05,
			})
		missions = new_missions
	# به‌روزرسانی پیشرفت
	for mission in missions:
		if mission.get("done", false):
			continue
		var progress: float = _progress(state, str(mission.get("id", "")))
		mission["progress"] = clamp(progress, 0.0, 1.0)
		if progress >= 1.0:
			mission["done"] = true
	state["missions"] = missions
	return {"state": state, "events": []}

func _progress(state: Dictionary, mission_id: String) -> float:
	match mission_id:
		"gdp_target":
			var gdp = float(state.get("economy", {}).get("gdp", 0.0))
			return clamp(gdp / (550_000_000_000.0 + float(state.get("tick", 1)) * 5_000_000_000.0), 0.0, 1.0)
		"law_enact":
			var enacted: Dictionary = state.get("legislation", {}).get("enacted", {})
			return clamp(float(enacted.size()) / 3.0, 0.0, 1.0)
		"build_road":
			var links: Array = state.get("map_advanced", {}).get("network_links", [])
			return clamp(float(links.size()) / 2.0, 0.0, 1.0)
		"win_war":
			var history: Array = state.get("world", {}).get("war_history", [])
			var wins := 0
			for w in history:
				if str(w.get("outcome", "")) == "victory":
					wins += 1
			return clamp(float(wins) / 1.0, 0.0, 1.0)
		"tech_research":
			var unlocked: Array = state.get("technology", {}).get("unlocked", [])
			return clamp(float(unlocked.size()) / 2.0, 0.0, 1.0)
		"improve_happiness":
			var happiness = float(state.get("population", {}).get("happiness", 0.6))
			return clamp((happiness - 0.55) / 0.2, 0.0, 1.0)
		"trade_agreement":
			var agreements: Array = state.get("world", {}).get("trade_agreements", [])
			return clamp(float(agreements.size()) / 1.0, 0.0, 1.0)
		"national_project":
			var projects: Dictionary = state.get("national_projects", {}).get("active", {})
			return clamp(float(projects.size()) / 1.0, 0.0, 1.0)
		"cabinet_stable":
			var cohesion = float(state.get("cabinet", {}).get("cohesion", 0.6))
			return clamp((cohesion - 0.5) / 0.3, 0.0, 1.0)
		"military_power":
			var power = float(state.get("military", {}).get("power", 60.0))
			return clamp((power - 60.0) / 20.0, 0.0, 1.0)
	return 0.0

func claim_reward(state: Dictionary, index: int) -> Dictionary:
	var missions: Array = state.get("missions", [])
	if index < 0 or index >= missions.size():
		return {"success": false, "reason": "مأموریت نامعتبر است"}
	var mission: Dictionary = missions[index]
	if not mission.get("done", false):
		return {"success": false, "reason": "این مأموریت هنوز کامل نشده است"}
	if mission.get("claimed", false):
		return {"success": false, "reason": "پاداش این مأموریت قبلاً دریافت شده است"}
	mission["claimed"] = true
	missions[index] = mission
	state["missions"] = missions
	# پاداش: اعتبار بین‌المللی + سرمایه سیاسی
	var diplomacy: Dictionary = state.get("diplomacy", {})
	diplomacy["prestige"] = float(diplomacy.get("prestige", 0.0)) + float(mission.get("reward_prestige", 8))
	state["diplomacy"] = diplomacy
	var policies: Dictionary = state.get("policies", {})
	policies["political_capital"] = float(policies.get("political_capital", 0.0)) + float(mission.get("reward_capital", 0.15))
	state["policies"] = policies
	return {"success": true, "mission": mission, "state": state}
