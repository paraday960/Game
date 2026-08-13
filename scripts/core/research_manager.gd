extends Node
# ────────────────────────────────────────────────────────────────────────────
# پژوهش و نوآوری ملی — عمق علم و فناوری
# جدا از درخت فناوری، زیست‌بوم پژوهشی کشور (دانشگاه، پژوهشگاه، شرکت دانش‌بنیان،
# مهاجرت نخبگان، ثبت اختراع و انتقال فناوری) را شبیه‌سازی می‌کند. پژوهش پایه
# بلندمدت است؛ تجاری‌سازی کوتاه‌مدت تولید می‌کند ولی ممکن است علم بنیادی آسیب ببیند.
# پیوند: فناوری، آموزش، صنعت، سلامت، مهاجرت، اقتصاد، فضای دیجیتال.
#
# state["research_policy"] = { "university_funding":0..1, "rnd_centers":0..1,
#   "tech_transfer":0..1, "commercialization":0..1, "brain_drain":0..1,
#   "papers":0, "patents":0, "last_center":turn, "last_grant":turn }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("research_policy"):
		state["research_policy"] = {
			"university_funding": 0.45, "rnd_centers": 0.25,
			"tech_transfer": 0.20, "commercialization": 0.30,
			"brain_drain": 0.28, "papers": 0, "patents": 0,
			"last_center": -99, "last_grant": -99, "innovation_index": 0.35
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var rp: Dictionary = state["research_policy"]
	var tech: Dictionary = state.get("technology", {})
	var edu: Dictionary = state.get("education", {})
	var econ: Dictionary = state.get("economy", {})
	var migration: Dictionary = state.get("migration_policy", {})
	var health: Dictionary = state.get("health", {})

	var university := float(rp.get("university_funding", 0.45))
	var centers := float(rp.get("rnd_centers", 0.25))
	var transfer := float(rp.get("tech_transfer", 0.20))
	var commercial := float(rp.get("commercialization", 0.30))
	var brain_drain := float(rp.get("brain_drain", 0.28))
	var literacy := float(edu.get("literacy", 0.85))
	var quality := float(edu.get("quality", 0.55))
	var gdp := float(econ.get("gdp", 1.0))
	var digital := float(tech.get("branch_levels", {}).get("دیجیتال", 0)) / 30.0
	var medical := float(tech.get("branch_levels", {}).get("پزشکی", 0)) / 30.0
	var industrial := float(tech.get("branch_levels", {}).get("صنعت", 0)) / 30.0

	# شاخص نوآوری ملی: آموزش + مراکز + انتقال فناوری + دیجیتال − فرار مغزها
	var innovation := clampf(
		0.12 + university * 0.20 + centers * 0.20 + quality * 0.18 + transfer * 0.14 +
		digital * 0.14 + commercial * 0.08 + industrial * 0.08 - brain_drain * 0.25,
		0.05, 1.0)
	rp["innovation_index"] = innovation

	# تولید علم و اختراع به‌صورت ماهانه
	var papers := int(round(innovation * (15.0 + literacy * 35.0) * (1.0 + university)))
	var patents := int(round(innovation * (2.0 + transfer * 12.0) * (1.0 + commercial * 0.7)))
	rp["papers"] = int(rp.get("papers", 0)) + papers
	rp["patents"] = int(rp.get("patents", 0)) + patents

	# بازخورد به درخت فناوری اصلی: نرخ پژوهش و باز شدن سریع‌تر شاخه‌ها
	if tech.has("research_rate"):
		tech["research_rate"] = clampf(float(tech.get("research_rate", 10.0)) * 0.995 + (5.0 + innovation * 25.0) * 0.005, 1.0, 100.0)
	if tech.has("branch_levels"):
		var levels: Dictionary = tech["branch_levels"]
		levels["صنعت"] = clampi(int(levels.get("صنعت", 4)) + (1 if centers > 0.55 and Deterministic.chance(0.01) else 0), 0, 30)
		levels["پزشکی"] = clampi(int(levels.get("پزشکی", 2)) + (1 if medical > 0.2 and university > 0.65 and Deterministic.chance(0.008) else 0), 0, 30)
		levels["دیجیتال"] = clampi(int(levels.get("دیجیتال", 3)) + (1 if digital > 0.2 and commercial > 0.55 and Deterministic.chance(0.009) else 0), 0, 30)
		tech["branch_levels"] = levels
	state["technology"] = tech

	# فرار مغزها با دستمزد/آزادی علمی/باز بودن مهاجرت
	var openness := float(migration.get("openness", 0.4)) if not migration.is_empty() else 0.4
	brain_drain = clampf(brain_drain + (openness - 0.5) * 0.004 - university * 0.003 - innovation * 0.002, 0.05, 0.80)
	rp["brain_drain"] = brain_drain
	state["population"]["migration_net"] = int(float(state["population"].get("migration_net", 10000)) - brain_drain * 1200.0 + innovation * 400.0)

	# بهره‌وری اقتصادی و سلامت ناشی از نوآوری
	econ["gdp"] = gdp * (1.0 + innovation * 0.0008 - brain_drain * 0.0004)
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - innovation * 0.00025 + commercial * 0.0001, 0.02, 0.30)
	health["quality"] = clampf(float(health.get("quality", 0.60)) + medical * 0.0005 + innovation * 0.0002, 0.1, 1.0)
	state["economy"] = econ
	state["health"] = health

	# هزینه بودجه پژوهشی
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + gdp * 0.002 * (0.4 + university + centers)
	state["economy"] = econ

	# رویدادها
	if innovation > 0.75 and Deterministic.chance(0.04):
		state["population"]["happiness"] = clampf(float(state["population"].get("happiness", 0.6)) + 0.004, 0.05, 1.0)
		events.append({"type": "innovation_boom", "message": "🔬 جهش علمی! اختراع‌ها و مقاله‌های راهبردی کشور را در نقشه دانش جهان بالا برد"})
	elif brain_drain > 0.55 and Deterministic.chance(0.05):
		state["politics"]["trust"] = clampf(float(state["politics"].get("trust", 0.55)) - 0.010, 0.05, 1.0)
		events.append({"type": "brain_drain", "message": "✈️ موج تازه مهاجرت نخبگان؛ دانشمندان و مهندسان به دنبال افق بهتر کشور را ترک کردند"})

	state["research_policy"] = rp
	return {"state": state, "events": events}

# ── افزایش بودجه دانشگاه‌ها ──
func fund_universities(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var rp: Dictionary = state["research_policy"]
	if float(rp.get("university_funding", 0.45)) >= 0.95:
		return {"success": false, "reason": "بودجه دانشگاه‌ها در سقف ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.004
	rp["university_funding"] = clampf(float(rp.get("university_funding", 0.45)) + 0.15, 0.0, 1.0)
	state["education"]["quality"] = clampf(float(state["education"].get("quality", 0.55)) + 0.015, 0.1, 1.0)
	rp["brain_drain"] = clampf(float(rp.get("brain_drain", 0.28)) - 0.02, 0.05, 0.80)
	state["research_policy"] = rp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "uni_funding", "message": "🎓 بودجه پژوهشی دانشگاه‌ها افزایش یافت؛ کیفیت آموزش و ماندگاری نخبگان بهتر شد"}]}

# ── احداث پژوهشگاه/مرکز تحقیقات راهبردی ──
func build_research_center(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var rp: Dictionary = state["research_policy"]
	if turn - int(rp.get("last_center", -99)) < 8:
		return {"success": false, "reason": "احداث مرکز پژوهشی هر ۸ نوبت یک بار ممکن است", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.006
	rp["rnd_centers"] = clampf(float(rp.get("rnd_centers", 0.25)) + 0.12, 0.0, 1.0)
	rp["last_center"] = turn
	econ["unemployment"] = clampf(float(econ.get("unemployment", 0.08)) - 0.0004, 0.02, 0.30)
	state["research_policy"] = rp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "research_center", "message": "🏛️ پژوهشگاه راهبردی جدید افتتاح شد؛ پروژه‌های بلندمدت علمی جان گرفتند"}]}

# ── تقویت دفاتر انتقال فناوری و تجاری‌سازی ──
func tech_transfer_program(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var rp: Dictionary = state["research_policy"]
	if float(rp.get("tech_transfer", 0.20)) >= 0.95:
		return {"success": false, "reason": "انتقال فناوری در حداکثر ممکن است", "state": state, "events": []}
	rp["tech_transfer"] = clampf(float(rp.get("tech_transfer", 0.20)) + 0.15, 0.0, 1.0)
	rp["commercialization"] = clampf(float(rp.get("commercialization", 0.30)) + 0.05, 0.0, 1.0)
	var factions: Dictionary = state.get("factions", {})
	if factions.has("نخبگان اقتصادی"):
		var f: Dictionary = factions["نخبگان اقتصادی"]
		f["loyalty"] = clampf(float(f.get("loyalty", 50.0)) + 1.5, 0.0, 100.0)
		factions["نخبگان اقتصادی"] = f
		state["factions"] = factions
	state["research_policy"] = rp
	return {"success": true, "state": state,
		"events": [{"type": "tech_transfer", "message": "🤝 دفاتر انتقال فناوری دانشگاه و صنعت به هم وصل شدند؛ شرکت‌های دانش‌بنیان رشد کردند"}]}

# ── بسته ماندگاری و بازگشت نخبگان ──
func retain_talent(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var rp: Dictionary = state["research_policy"]
	if turn - int(rp.get("last_grant", -99)) < 6:
		return {"success": false, "reason": "بسته نخبگان هر ۶ نوبت یک بار قابل اجراست", "state": state, "events": []}
	var econ: Dictionary = state.get("economy", {})
	econ["government_spending"] = float(econ.get("government_spending", 0.0)) + float(econ.get("gdp", 1.0)) * 0.0025
	rp["last_grant"] = turn
	rp["brain_drain"] = clampf(float(rp.get("brain_drain", 0.28)) - 0.10, 0.05, 0.80)
	rp["innovation_index"] = clampf(float(rp.get("innovation_index", 0.35)) + 0.03, 0.05, 1.0)
	state["population"]["migration_net"] = int(float(state["population"].get("migration_net", 10000)) + 15000)
	state["research_policy"] = rp
	state["economy"] = econ
	return {"success": true, "state": state,
		"events": [{"type": "retain_talent", "message": "🧲 بورس، آزمایشگاه و جایگاه شغلی برای نخبگان فراهم شد؛ موج بازگشت دانشمندان آغاز شد"}]}
