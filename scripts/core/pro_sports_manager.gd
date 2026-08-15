extends Node
# اقتصاد ورزش حرفه‌ای — لیگ‌های پولی، زیرساخت، میزبانی رویداد، آکادمی و صادرات صنعت ورزش.
# کلید state جدا از sports_policy قدیمی: pro_sports_policy


var leagues: float = 0.20
var infrastructure: float = 0.20
var events: float = 0.10
var youth_academy: float = 0.20
var sports_exports: float = 0.05
var industry_index: float = 0.0

func reset():
	leagues = 0.20; infrastructure = 0.20; events = 0.10
	youth_academy = 0.20; sports_exports = 0.05; industry_index = 0.0

func _ensure(state: Dictionary):
	if not state.has("pro_sports_policy"):
		state["pro_sports_policy"] = {
			"leagues": leagues, "infrastructure": infrastructure, "events": events,
			"academy": youth_academy, "exports": sports_exports, "index": industry_index,
		}

func get_policy(state: Dictionary) -> Dictionary:
	_ensure(state); return state["pro_sports_policy"]

func develop_leagues(state): _ensure(state); var p=state["pro_sports_policy"]; p["leagues"]=clampf(float(p.get("leagues", 0.0))+0.12,0,1); state["pro_sports_policy"]=p; return {"success":true}
func build_infrastructure(state):
	_ensure(state); var p=state["pro_sports_policy"]
	if float(state.get("economy",{}).get("gdp",0))<=0: return {"success":false,"reason":"اقتصاد فعالی وجود ندارد"}
	p["infrastructure"]=clampf(float(p.get("infrastructure", 0.0))+0.12,0,1); state["pro_sports_policy"]=p; return {"success":true}
func host_events(state):
	_ensure(state); var p=state["pro_sports_policy"]
	if float(p.get("infrastructure", 0.0))<0.3: return {"success":false,"reason":"به زیرساخت ورزشی بیشتری نیاز است"}
	p["events"]=clampf(float(p.get("events", 0.0))+0.12,0,1); state["pro_sports_policy"]=p; return {"success":true}
func develop_academy(state): _ensure(state); var p=state["pro_sports_policy"]; p["academy"]=clampf(float(p.get("academy", 0.0))+0.12,0,1); state["pro_sports_policy"]=p; return {"success":true}
func boost_exports(state): _ensure(state); var p=state["pro_sports_policy"]; p["exports"]=clampf(float(p.get("exports", 0.0))+0.12,0,1); state["pro_sports_policy"]=p; return {"success":true}

func simulate(state: Dictionary, tick: int) -> Dictionary:
	_ensure(state)
	var p=state["pro_sports_policy"]
	var econ=state.get("economy",{}); var gdp=float(econ.get("gdp",0))
	var stability=float(state.get("politics",{}).get("stability",0.5))
	var lg=float(p.get("leagues", 0.0)); var infra=float(p.get("infrastructure", 0.0)); var ev=float(p.get("events", 0.0)); var acad=float(p.get("academy", 0.0)); var exp=float(p.get("exports", 0.0))
	var index=clampf(lg*0.25+infra*0.25+ev*0.20+acad*0.15+exp*0.15,0,1)*clampf(stability,0.3,1)
	industry_index=index; p["index"]=index
	if gdp>0:
		# ممیزی GDP (۱۴۰۵): جمع ماهانهٔ بی‌قید (تا +۶٪/سال انباشتی) → کانال نرخ سالانه
		var ps_boosts: Dictionary = econ.get("sector_boosts", {})
		ps_boosts["ورزش حرفه‌ای"] = index * 0.005 * 12.0
		econ["sector_boosts"] = ps_boosts
		# درآمد ارزی رویدادها/صادرات ورزشی → کانال reserve_inflows (بازرسی ۱۴۰۵)
		var ps_infl: Dictionary = econ.get("reserve_inflows", {})
		ps_infl["رویدادها و صادرات ورزشی"] = (gdp*(ev*0.001+exp*0.001)) if (ev>0.0 or exp>0.0) else 0.0
		econ["reserve_inflows"] = ps_infl
		state["economy"]=econ
	var health=state.get("health",{})
	if not health.is_empty(): health["quality"]=clampf(float(health.get("quality",0.5))+acad*0.0008,0,1); state["health"]=health
	var tourism=state.get("tourism",{})
	if tourism.has("tourists"): tourism["tourists"]=float(tourism.get("tourists",0))+ev*50.0; state["tourism"]=tourism
	var culture=state.get("culture_policy",{})
	if not culture.is_empty(): culture["soft_power"]=clampf(float(culture.get("soft_power",40))+ev*0.002,5,100); state["culture_policy"]=culture
	state["pro_sports_policy"]=p
	return state

func simulate_month(state: Dictionary, tick: int) -> Dictionary:
	# قرارداد مشترک چرخه ماهانه موتور: خروجی همیشه {state, events} است؛
	# simulate خام state را برمی‌گرداند (سازگار با تست‌ها) پس اینجا بسته‌بندی می‌شود.
	return {"state": simulate(state, tick), "events": []}
func get_summary(state): var p=get_policy(state); return {"leagues":p["leagues"],"infrastructure":p["infrastructure"],"events":p["events"],"academy":p["academy"],"exports":p["exports"],"index":p["index"]}
