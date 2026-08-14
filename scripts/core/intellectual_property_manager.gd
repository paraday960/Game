extends Node
# ────────────────────────────────────────────────────────────────────────────
# مالکیت فکری و تجاری‌سازی دانش — عمق نوآوری
# ثبت اختراع، حمایت از کپی‌رایت، پارک علم و فناوری و قرارداد انتقال فناوری.
# IP قوی سرمایه‌گذاری و FDI را جذب می‌کند و تجاری‌سازی پژوهش را بالا می‌برد.
# پیوند: پژوهش، استارتاپ، آموزش عالی، صنعت، دیپلماسی علمی.
#
# state["ip_policy"] = {
#   "patents":0..1, "copyright":0..1, "tech_transfer":0..1,
#   "enforcement":0..1, "last_reform":turn,
#   "innovation_index":0..1, "patent_count":0 }
# ────────────────────────────────────────────────────────────────────────────
func ensure(state: Dictionary) -> Dictionary:
	if not state.has("ip_policy"):
		state["ip_policy"] = {
			"patents": 0.25, "copyright": 0.30, "tech_transfer": 0.20,
			"enforcement": 0.30, "last_reform": -99,
			"innovation_index": 0.25, "patent_count": 500,
			"royalty_income": 0.05, "ip_compliance": 0.40
		}
	return state

func simulate_month(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var events: Array = []
	var ip: Dictionary = state["ip_policy"]
	var research: Dictionary = state.get("research_policy", {})
	var startups: Dictionary = state.get("startup_policy", {})
	var fdi: Dictionary = state.get("fdi_policy", {})
	var higher_ed: Dictionary = state.get("higher_ed_policy", {})
	var econ: Dictionary = state.get("economy", {})

	var patents: float = float(ip.get("patents", 0.25))
	var copyright: float = float(ip.get("copyright", 0.30))
	var transfer: float = float(ip.get("tech_transfer", 0.20))
	var enforce: float = float(ip.get("enforcement", 0.30))

	# شاخص نوآوری: پژوهش + IP + آموزش عالی
	var research_innov: float = float(research.get("innovation_index", 0.30))
	var uni_quality: float = float(higher_ed.get("quality", 0.35))
	var innov: float = clampf(
		0.10 + patents * 0.25 + transfer * 0.20 + enforce * 0.15 +
		research_innov * 0.25 + uni_quality * 0.15, 0.05, 0.98)
	ip["innovation_index"] = innov
	ip["ip_compliance"] = clampf(0.20 + enforce * 0.50 + copyright * 0.20, 0.05, 0.98)

	# درآمد حق امتیاز/رویالتی
	var royalty: float = clampf(innov * 0.20 + patents * 0.15 + transfer * 0.10, 0.0, 0.80)
	ip["royalty_income"] = royalty

	# تعداد اختراعات
	var new_patents: int = int(innov * 300.0 + research_innov * 200.0)
	var count: int = int(ip.get("patent_count", 500)) + new_patents
	ip["patent_count"] = count

	# اثر اقتصادی: تجاری‌سازی → رشد و استارتاپ
	var gdp: float = float(econ.get("gdp", 1.0))
	# ممیزی GDP (۱۴۰۵): اثر مداوم از کانال مالک-یکتای sector_boosts (نرخ سالانه؛ ماهانه: ×۱۲)
	var (innov * 0.0005 + royalty * 0.0003) * 12.0_boosts: Dictionary = econ.get("sector_boosts", {})
	(innov * 0.0005 + royalty * 0.0003) * 12.0_boosts["نوآوری و مالکیت فکری"] = (innov * 0.0005 + royalty * 0.0003) * 12.0
	econ["sector_boosts"] = (innov * 0.0005 + royalty * 0.0003) * 12.0_boosts
	# درآمد رویالتی به خزانه (بازرسی کلید یتیم ۱۴۰۵): شاخص royalty_income قبلاً فقط
	# دفترداری می‌شد و پولی جریان نمی‌یافت؛ حالا ~۰٫۰۲٪ GDP نرخ ماهانه عبر کانال استاندارد.
	econ["royalty_revenue_monthly"] = gdp * royalty * 0.0002
	state["economy"] = econ

	if not startups.is_empty():
		startups["innovation_rate"] = clampf(float(startups.get("innovation_rate", 0.20)) + innov * 0.001, 0.05, 1.0)
		state["startup_policy"] = startups

	# FDI با حفاظت IP
	if fdi.has("protection"):
		fdi["protection"] = clampf(float(fdi.get("protection", 0.40)) + enforce * 0.002, 0.0, 1.0)
		state["fdi_policy"] = fdi

	# رویدادها
	if innov > 0.70 and Deterministic.chance(0.03):
		events.append({"type": "patent_boom", "message": "📈 ثبت اختراعات ملی رکورد شکست؛ شرکت‌های فناور رشد کردند"})
	elif enforce < 0.25 and Deterministic.chance(0.04):
		events.append({"type": "piracy_risk", "message": "🏴 نقض گسترده مالکیت فکری، سرمایه‌گذاری خارجی ترسید"})
	elif transfer > 0.60 and Deterministic.chance(0.02):
		events.append({"type": "tech_transfer_win", "message": "🤝 قرارداد بزرگ انتقال فناوری با یک شرکت خارجی منعقد شد"})

	state["ip_policy"] = ip
	return {"state": state, "events": events}

func patent_reform(state: Dictionary, turn: int) -> Dictionary:
	state = ensure(state)
	var ip: Dictionary = state["ip_policy"]
	if turn - int(ip.get("last_reform", -99)) < 5:
		return {"success": false, "reason": "اصلاح نظام ثبت اختراع هر ۵ نوبت یک بار", "state": state, "events": []}
	ip["last_reform"] = turn
	ip["patents"] = clampf(float(ip.get("patents", 0.25)) + 0.15, 0.0, 1.0)
	ip["enforcement"] = clampf(float(ip.get("enforcement", 0.30)) + 0.05, 0.0, 1.0)
	state["ip_policy"] = ip
	return {"success": true, "state": state,
		"events": [{"type": "patent_reform", "message": "📜 نظام ثبت اختراع اصلاح و تسریع شد"}]}

func strengthen_copyright(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ip: Dictionary = state["ip_policy"]
	ip["copyright"] = clampf(float(ip.get("copyright", 0.30)) + 0.15, 0.0, 1.0)
	ip["enforcement"] = clampf(float(ip.get("enforcement", 0.30)) + 0.08, 0.0, 1.0)
	state["ip_policy"] = ip
	return {"success": true, "state": state,
		"events": [{"type": "copyright", "message": "© قانون کپی‌رایت و مقابله با سرقت ادبی تقویت شد"}]}

func tech_transfer_office(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ip: Dictionary = state["ip_policy"]
	ip["tech_transfer"] = clampf(float(ip.get("tech_transfer", 0.20)) + 0.15, 0.0, 1.0)
	state["ip_policy"] = ip
	return {"success": true, "state": state,
		"events": [{"type": "tto", "message": "🏢 دفاتر انتقال فناوری دانشگاه‌ها راه‌اندازی شد"}]}

func science_park(state: Dictionary) -> Dictionary:
	state = ensure(state)
	var ip: Dictionary = state["ip_policy"]
	if float(ip.get("tech_transfer", 0.20)) >= 0.95:
		return {"success": false, "reason": "پارک علم و فناوری در سقف است", "state": state, "events": []}
	ip["tech_transfer"] = clampf(float(ip.get("tech_transfer", 0.20)) + 0.15, 0.0, 1.0)
	ip["patents"] = clampf(float(ip.get("patents", 0.25)) + 0.05, 0.0, 1.0)
	state["ip_policy"] = ip
	return {"success": true, "state": state,
		"events": [{"type": "science_park", "message": "🔬 پارک علم و فناوری توسعه یافت؛ شرکت‌ها به دانشگاه وصل شدند"}]}
