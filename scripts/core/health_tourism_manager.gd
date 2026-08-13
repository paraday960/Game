extends Node
# ── گردشگری سلامت (توریسم درمانی) ──
# جذب بیمار خارجی برای درمان، توریسم پیشگیری، آب‌درمانی و گردشگری
# پزشکی. این صنعت به ارزآوری، اشتغال کادر درمان و قدرت نرم کمک می‌کند
# اما به زیرساخت بهداشت و ثبات نیاز دارد. پیوند: بهداشت، گردشگری، دیپلماسی.

signal health_tourists_changed(count: float)

var hospitals: float = 0.20        # بیمارستان‌های بین‌المللی
var medical_quality: float = 0.30
var wellness: float = 0.15         # آب‌درمانی/پیشگیری
var visa_facilitation: float = 0.20
var accreditation: float = 0.15
var marketing: float = 0.10
var tourist_count: float = 0.0
var revenue: float = 0.0
var last_tick: int = 0

func reset():
	hospitals = 0.20
	medical_quality = 0.30
	wellness = 0.15
	visa_facilitation = 0.20
	accreditation = 0.15
	marketing = 0.10
	tourist_count = 0.0
	revenue = 0.0

func _ensure(state: Dictionary):
	if not state.has("health_tourism_policy"):
		state["health_tourism_policy"] = {
			"hospitals": hospitals,
			"quality": medical_quality,
			"wellness": wellness,
			"visa": visa_facilitation,
			"accreditation": accreditation,
			"marketing": marketing,
			"tourists": tourist_count,
			"revenue": revenue,
			"last_tick": last_tick,
		}

func get_policy(state: Dictionary) -> Dictionary:
	_ensure(state)
	return state["health_tourism_policy"]

func build_international_hospital(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["health_tourism_policy"]
	p["hospitals"] = clampf(float(p["hospitals"]) + 0.12, 0.0, 1.0)
	state["health_tourism_policy"] = p
	return {"success": true}

func improve_quality(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["health_tourism_policy"]
	p["quality"] = clampf(float(p["quality"]) + 0.10, 0.0, 1.0)
	state["health_tourism_policy"] = p
	return {"success": true}

func develop_wellness(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["health_tourism_policy"]
	p["wellness"] = clampf(float(p["wellness"]) + 0.12, 0.0, 1.0)
	state["health_tourism_policy"] = p
	return {"success": true}

func facilitate_visa(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["health_tourism_policy"]
	p["visa"] = clampf(float(p["visa"]) + 0.12, 0.0, 1.0)
	state["health_tourism_policy"] = p
	return {"success": true}

func international_accreditation(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["health_tourism_policy"]
	if float(p["quality"]) < 0.35:
		return {"success": false, "reason": "ابتدا کیفیت درمان را ارتقا دهید"}
	p["accreditation"] = clampf(float(p["accreditation"]) + 0.12, 0.0, 1.0)
	state["health_tourism_policy"] = p
	return {"success": true}

func marketing_campaign(state: Dictionary) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["health_tourism_policy"]
	p["marketing"] = clampf(float(p["marketing"]) + 0.12, 0.0, 1.0)
	state["health_tourism_policy"] = p
	return {"success": true}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	_ensure(state)
	var p: Dictionary = state["health_tourism_policy"]
	var economy: Dictionary = state.get("economy", {})
	var gdp: float = float(economy.get("gdp", 0.0))
	var health: Dictionary = state.get("health", {})
	var stability: float = float(state.get("politics", {}).get("stability", 0.5))

	# ظرفیت جذب گردشگر سلامت
	var quality: float = float(p["quality"])
	var capacity: float = (
		float(p["hospitals"]) * 0.35 +
		quality * 0.25 +
		float(p["wellness"]) * 0.15 +
		float(p["accreditation"]) * 0.15 +
		float(p["visa"]) * 0.05 +
		float(p["marketing"]) * 0.05
	)
	# تأثیر ثبات و اعتبار بین‌المللی
	capacity *= clampf(stability, 0.2, 1.0)
	# هر واحد ظرفیت ≈ تعداد گردشگر سلامت (هزار نفر در ماه)
	var target_tourists: float = capacity * 500.0
	var current: float = float(p["tourists"])
	var new_count: float = lerp(current, target_tourists, 0.10)
	p["tourists"] = new_count

	# درآمد ارزی (هر گردشگر سلامت به‌طور متوسط)
	var spend_per_tourist: float = 3500.0 + quality * 5000.0
	var new_revenue: float = new_count * 1000.0 * spend_per_tourist / 12.0  # ماهانه
	p["revenue"] = new_revenue
	p["last_tick"] = tick

	if gdp > 0.0:
		# واقع‌گرایی: اثر سطحی همگرا (هر ماه ۲۰٪ از فاصله تا هدف) به‌جای جمعِ بی‌پایان روی GDP
		var boost_target: float = new_revenue * 0.5
		var boost_prev: float = float(p.get("_gdp_boost", 0.0))
		var boost_delta: float = (boost_target - boost_prev) * 0.20
		economy["gdp"] = gdp + boost_delta
		p["_gdp_boost"] = boost_prev + boost_delta
		economy["foreign_reserves"] = float(economy.get("foreign_reserves", 0.0)) + new_revenue * 0.3
		state["economy"] = economy

	# بهبود سلامت و رضایت
	if not health.is_empty():
		health["quality"] = clampf(float(health.get("quality", 0.5)) + quality * 0.0005, 0.0, 1.0)
		state["health"] = health
	# قدرت نرم
	if state.has("diplomacy") and state["diplomacy"] is Dictionary:
		var dip: Dictionary = state["diplomacy"]
		dip["soft_power"] = clampf(float(dip.get("soft_power", 35.0)) + new_count * 0.0001, 0.0, 100.0)
		state["diplomacy"] = dip

	emit_signal("health_tourists_changed", new_count)
	state["health_tourism_policy"] = p
	return state

func get_summary(state: Dictionary) -> Dictionary:
	var p = get_policy(state)
	return {
		"hospitals": p["hospitals"],
		"quality": p["quality"],
		"wellness": p["wellness"],
		"visa": p["visa"],
		"accreditation": p["accreditation"],
		"tourists": p["tourists"],
		"revenue": p["revenue"],
	}

# سازگاری با چرخه‌ی ماهانه‌ی GameEngine
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	# قرارداد مشترک چرخه ماهانه موتور: خروجی همیشه {state, events} است؛
	# simulate خام state را برمی‌گرداند (سازگار با تست‌ها) پس اینجا بسته‌بندی می‌شود.
	return {"state": simulate(state, turn), "events": []}
