extends Node
# ── نظام مالیات و درآمد دولت ──
# نرخ‌های مالیات، پایه مالیاتی، فرار مالیاتی و درآمد پایدار.
# مالیات هوشمند می‌تواند درآمد را بدون فشار زیاد افزایش دهد؛ فرار مالیاتی
# درآمد را کم می‌کند و رفاه را تحت‌تأثیر قرار می‌دهد.
# پیوند: اقتصاد، رفاه، صنایع، رضایت مردم.

signal tax_revenue_changed(total_revenue: float)

var tax_rates: Dictionary = {
	"income": 0.12,
	"corporate": 0.18,
	"vat": 0.09,
	"wealth": 0.0,
}
var tax_compliance: float = 0.65  # پایبندی مالیاتی (۱-فرار)
var digital_invoicing: float = 0.20
var tax_brackets: int = 3
var total_revenue: float = 0.0
var revenue_to_gdp: float = 0.0
var last_tick: int = 0

const MIN_RATE := 0.0
const MAX_RATE := 0.50

func reset():
	tax_rates = {"income": 0.12, "corporate": 0.18, "vat": 0.09, "wealth": 0.0}
	tax_compliance = 0.65
	digital_invoicing = 0.20
	tax_brackets = 3
	total_revenue = 0.0
	revenue_to_gdp = 0.0

func _ensure_state(state: Dictionary):
	if not state.has("tax_policy"):
		state["tax_policy"] = {
			"rates": tax_rates.duplicate(true),
			"compliance": tax_compliance,
			"digital": digital_invoicing,
			"brackets": tax_brackets,
			"revenue": total_revenue,
			"last_tick": last_tick,
		}

func get_policy(state: Dictionary) -> Dictionary:
	_ensure_state(state)
	return state["tax_policy"]

func set_rate(state: Dictionary, tax_type: String, value: float) -> Dictionary:
	_ensure_state(state)
	var p: Dictionary = state["tax_policy"]
	var clamped: float = clampf(value, MIN_RATE, MAX_RATE)
	if not p["rates"].has(tax_type):
		return {"success": false, "reason": "نوع مالیات نامعتبر است"}
	var old: float = float(p["rates"][tax_type])
	p["rates"][tax_type] = clamped
	state["tax_policy"] = p
	return {"success": true, "old_rate": old, "new_rate": clamped}

func improve_compliance(state: Dictionary, amount: float = 0.10) -> Dictionary:
	_ensure_state(state)
	var p: Dictionary = state["tax_policy"]
	p["compliance"] = clampf(float(p["compliance"]) + amount, 0.1, 0.98)
	state["tax_policy"] = p
	return {"success": true, "compliance": p["compliance"]}

func deploy_digital_invoicing(state: Dictionary) -> Dictionary:
	_ensure_state(state)
	var p: Dictionary = state["tax_policy"]
	p["digital"] = clampf(float(p["digital"]) + 0.15, 0.0, 1.0)
	state["tax_policy"] = p
	return {"success": true}

func add_bracket(state: Dictionary) -> Dictionary:
	_ensure_state(state)
	var p: Dictionary = state["tax_policy"]
	p["brackets"] = mini(int(p["brackets"]) + 1, 8)
	state["tax_policy"] = p
	return {"success": true, "brackets": p["brackets"]}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	_ensure_state(state)
	var p: Dictionary = state["tax_policy"]
	var economy: Dictionary = state.get("economy", {})
	var gdp: float = float(economy.get("gdp", 0.0))
	if gdp <= 0.0:
		return state

	# ضرایب تقریبی پایه برای هر نوع مالیات نسبت به GDP
	# (مدل ساده: درصدی از GDP با ضریب پایبندی)
	var rates: Dictionary = p["rates"]
	var compliance: float = float(p["compliance"])
	var digital: float = float(p["digital"])
	# دیجیتالی شدن، فرار را کم می‌کند
	var effective_compliance: float = clampf(compliance + digital * 0.25, 0.1, 0.99)

	# ضرایب کشش: نرخ بالاتر از آستانه، پایه را به‌خاطر فرار/کاهش فعالیت کم می‌کند
	var income_eff: float = (1.0 - maxf(0.0, float(rates.get("income", 0.0)) - 0.25) * 1.5) * effective_compliance
	var corporate_eff: float = (1.0 - maxf(0.0, float(rates.get("corporate", 0.0)) - 0.30) * 1.2) * effective_compliance
	var vat_eff: float = effective_compliance
	var wealth_eff: float = effective_compliance

	var revenue: float = 0.0
	revenue += gdp * 0.42 * float(rates.get("income", 0.0)) * income_eff
	revenue += gdp * 0.30 * float(rates.get("corporate", 0.0)) * corporate_eff
	revenue += gdp * 0.35 * float(rates.get("vat", 0.0)) * vat_eff
	revenue += gdp * 0.50 * float(rates.get("wealth", 0.0)) * wealth_eff

	# پلکانی بودن، بار طبقات پایین را کم و درآمد کل را کمی بالا می‌برد
	var bracket_bonus: float = 1.0 + (int(p["brackets"]) - 3) * 0.015
	revenue *= bracket_bonus

	p["revenue"] = revenue
	p["last_tick"] = tick
	revenue_to_gdp = revenue / gdp if gdp > 0.0 else 0.0
	state["tax_policy"] = p

	# درآمد به بودجه دولت تزریق می‌شود (اگر کلید بودجه وجود داشت)
	if state.has("budget") and state["budget"] is Dictionary:
		var budget: Dictionary = state["budget"]
		budget["tax_revenue"] = revenue
		# کاهش کسری با فرض ثبات سایر هزینه‌ها (ساده)
		if budget.has("deficit"):
			budget["deficit"] = maxf(0.0, float(budget["deficit"]) - revenue * 0.5)
		state["budget"] = budget

	emit_signal("tax_revenue_changed", revenue)
	return state

func get_summary(state: Dictionary) -> Dictionary:
	var p = get_policy(state)
	return {
		"rates": p["rates"],
		"compliance": p["compliance"],
		"digital": p["digital"],
		"brackets": p["brackets"],
		"revenue": p.get("revenue", 0.0),
		"revenue_to_gdp": revenue_to_gdp,
	}

# سازگاری با چرخه‌ی ماهانه‌ی GameEngine
func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	# قرارداد مشترک چرخه ماهانه موتور: خروجی همیشه {state, events} است؛
	# simulate خام state را برمی‌گرداند (سازگار با تست‌ها) پس اینجا بسته‌بندی می‌شود.
	return {"state": simulate(state, turn), "events": []}
