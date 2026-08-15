extends BaseAI
# ── مشاور مدیریت بحران (عمق‌بخشی ۷) ───────────────────────────────────────
# واکنش به بحران‌های فعال (events_active): برخلاف هوش‌های تخصصی که شاخص
# بخش خودشان را می‌بینند، این مشاور «تصویر کل بحران» را می‌سنجد و توصیه‌ی
# بودجه‌ای هدفمند برای بحران جاری می‌دهد (پاندمی → بهداشت، بحران ارزی →
# ذخیره، شورش → رفاه، خشکسالی → کشاورزی). فقط وقتی بحران واقعی فعال است
# توصیه می‌کند؛ در آرامش ساکت می‌ماند.

# نگاشت نوع بحران/نخ به ردیف بودجه‌ی واکنش درست (کلیدهای واقعی budget_allocations)
const CRISIS_BUDGET_MAP := {
	"epidemic_outbreak": "بهداشت",
	"epidemic_wave2": "بهداشت",
	"drought_chain": "زیرساخت",
	"drought": "زیرساخت",
	"mass_protest": "رفاه",
	"banking_chain": "ذخیره",
	"banking_crisis": "ذخیره",
	"currency_crisis": "ذخیره",
	"sanctions_chain": "ذخیره",
	"oil_shock_world": "زیرساخت",
	"chokepoint_chain": "زیرساخت",
	"debt_crisis": "ذخیره",
	"housing_crisis": "رفاه",
	"natural_disaster": "ذخیره",
	"border_tension": "ارتش",
	"refugee_wave_chain": "رفاه",
	"demographic_winter_chain": "رفاه",
	"ai_revolution_chain": "آموزش",
	"election_shock_chain": "ذخیره",
	"brain_drain": "آموزش",
	"trade_deficit_crisis": "ذخیره",
	"cyber_attack": "ارتش"
}

func get_system_key() -> String:
	return "crisis"

func diagnose(state: Dictionary) -> Dictionary:
	var active: Array = state.get("events_active", [])
	var weight := 0.0
	var worst_type := ""
	var worst_title := ""
	var worst_severity := 0
	for c in active:
		if str(c.get("status", "active")) != "active":
			continue
		weight += float(c.get("severity", 1))
		if int(c.get("severity", 1)) > worst_severity:
			worst_severity = int(c.get("severity", 1))
			worst_type = str(c.get("type", ""))
			worst_title = str(c.get("title", "بحران"))
	# فشارهای کلان (مثل شاخص بحران جهان)
	var econ: Dictionary = state.get("economy", {})
	if float(econ.get("debt_to_gdp", 0.0)) > 1.2:
		weight += 2.0
	if float(econ.get("inflation", 0.0)) > 0.25:
		weight += 2.0
	if float(econ.get("foreign_reserves", 0.0)) < 15_000_000_000.0:
		weight += 1.0
	var pol: Dictionary = state.get("politics", {})
	if float(pol.get("stability", 0.6)) < 0.35:
		weight += 1.5
	if weight <= 0.0:
		# در آرامش: تشخیص خنثی (health=1، urgency=0) تا شورای هوشمند بتواند
		# همه‌ی agent ها را بشمارد؛ هیچ فرمانی ساخته نمی‌شود.
		return {
			"system": "crisis",
			"title": "مدیریت بحران",
			"metric_path": "events_active",
			"value": 0.0,
			"target": 0.0,
			"health": 1.0,
			"urgency": 0.0,
			"budget_key": "ذخیره",
			"reason": "هیچ بحران فعالی وجود ندارد؛ سامانه در وضعیت عادی است"
		}

	var urgency := clampf(weight / 8.0, 0.0, 1.0)
	var health := 1.0 - urgency
	# ردیف بودجه‌ی واکنش: اول نوع بحران، بعد فشار عمومی → ذخیره
	var budget_key := "ذخیره"
	if worst_type != "" and CRISIS_BUDGET_MAP.has(worst_type):
		budget_key = CRISIS_BUDGET_MAP[worst_type]
	elif weight >= 4.0:
		budget_key = "ذخیره"
	var title := "مدیریت بحران"
	if worst_title != "":
		title = "پاسخ به «%s»" % worst_title
	var result := {
		"system": "crisis",
		"title": title,
		"metric_path": "events_active",
		"value": weight,
		"target": 0.0,
		"health": health,
		"urgency": urgency,
		"budget_key": budget_key,
		"reason": _explain(title, "low", urgency) if worst_type == "" else "بحران فعال «%s»؛ تخصیص بودجه به %s برای مهار پیامدها" % [worst_title, budget_key]
	}
	if urgency > 0.05:
		var cmd = build_budget_command(state, budget_key)
		if cmd != null:
			result["command"] = cmd.to_dict()
	return result

func decide(state: Dictionary, tick: int) -> Array:
	var d = diagnose(state)
	if float(d.get("urgency", 0.0)) < 0.15:
		return []
	var cmd = build_budget_command(state, str(d.get("budget_key", "ذخیره")))
	return [cmd] if cmd != null else []

func evaluate(state: Dictionary) -> float:
	return float(diagnose(state).get("health", 1.0))
