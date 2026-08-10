extends RefCounted
class_name DecisionManager
# تبدیل رویدادهای شبیه‌سازی به تصمیم‌های چندگزینه‌ای با پیامد اتمی و قابل ذخیره

const MAX_PENDING = 6
const MAX_HISTORY = 200
const DECISION_LIFETIME = 30

const TEMPLATES = {
	"drought": {
		"title": "خشکسالی گسترده",
		"description": "بارش کم، ذخایر آب و تولید غذا را تهدید می‌کند. دولت باید میان واردات فوری، سهمیه‌بندی و سرمایه‌گذاری پایدار انتخاب کند.",
		"choices": [
			{"id": "import", "text": "واردات فوری آب و غذا", "consequence": "ذخایر سریع‌تر ترمیم می‌شود اما بدهی افزایش می‌یابد.", "effects": [
				{"path":"resources.inventory.غذا","op":"add","value":25.0,"min":0.0,"max":150.0},
				{"path":"resources.inventory.آب","op":"add","value":20.0,"min":0.0,"max":150.0},
				{"path":"economy.national_debt","op":"add","value":3000000000.0}]},
			{"id": "ration", "text": "سهمیه‌بندی سراسری", "consequence": "مصرف مهار می‌شود ولی رضایت عمومی کاهش می‌یابد.", "effects": [
				{"path":"resources.inventory.آب","op":"add","value":12.0,"min":0.0,"max":150.0},
				{"path":"population.happiness","op":"add","value":-0.035,"min":0.0,"max":1.0}]},
			{"id": "irrigation", "text": "سرمایه‌گذاری در آبیاری نوین", "consequence": "هزینه زیاد است اما کشاورزی و زیرساخت پایدارتر می‌شوند.", "effects": [
				{"path":"agriculture.irrigated_land","op":"add","value":0.08,"min":0.0,"max":1.0},
				{"path":"infrastructure.quality","op":"add","value":0.012,"min":0.0,"max":1.0},
				{"path":"economy.national_debt","op":"add","value":5000000000.0}]}
		]
	},
	"epidemic_outbreak": {
		"title": "شیوع بیماری واگیردار",
		"description": "شبکه درمان با موج بیماران روبه‌رو شده است. تأخیر در واکنش می‌تواند تلفات و بی‌اعتمادی را افزایش دهد.",
		"choices": [
			{"id":"mobilize", "text":"بسیج کامل نظام سلامت", "consequence":"آمادگی و پوشش درمان بالا می‌رود و بدهی افزایش می‌یابد.", "effects":[
				{"path":"health.epidemic_readiness","op":"add","value":0.15,"min":0.0,"max":1.0},
				{"path":"health.coverage","op":"add","value":0.05,"min":0.0,"max":1.0},
				{"path":"economy.national_debt","op":"add","value":4000000000.0}]},
			{"id":"targeted", "text":"محدودیت هدفمند و واکسیناسیون", "consequence":"تعادل میان اقتصاد و سلامت حفظ می‌شود.", "effects":[
				{"path":"health.vaccination","op":"add","value":0.07,"min":0.0,"max":1.0},
				{"path":"health.epidemic_readiness","op":"add","value":0.08,"min":0.0,"max":1.0},
				{"path":"economy.growth_rate","op":"add","value":-0.002,"min":-0.05,"max":0.08}]},
			{"id":"delay", "text":"حفظ فعالیت عادی و پایش", "consequence":"هزینه فوری ندارد اما سلامت و اعتماد آسیب می‌بیند.", "effects":[
				{"path":"health.quality","op":"add","value":-0.05,"min":0.0,"max":1.0},
				{"path":"population.happiness","op":"add","value":-0.025,"min":0.0,"max":1.0},
				{"path":"politics.trust","op":"add","value":-0.03,"min":0.0,"max":1.0}]}
		]
	},
	"mass_protest": {
		"title": "اعتراضات گسترده",
		"description": "نارضایتی اقتصادی و سیاسی به خیابان رسیده است. نحوه واکنش، اعتماد و ثبات آینده را شکل می‌دهد.",
		"choices": [
			{"id":"dialogue", "text":"گفت‌وگوی ملی و اصلاحات", "consequence":"اعتماد و ثبات با هزینه اداری ترمیم می‌شود.", "effects":[
				{"path":"politics.trust","op":"add","value":0.06,"min":0.0,"max":1.0},
				{"path":"politics.tension","op":"add","value":-0.08,"min":0.0,"max":1.0},
				{"path":"administration.efficiency","op":"add","value":-0.015,"min":0.0,"max":1.0}]},
			{"id":"welfare", "text":"بسته فوری معیشتی", "consequence":"رضایت سریع بالا می‌رود اما بدهی بیشتر می‌شود.", "effects":[
				{"path":"population.happiness","op":"add","value":0.05,"min":0.0,"max":1.0},
				{"path":"welfare.poverty","op":"add","value":-0.025,"min":0.0,"max":1.0},
				{"path":"economy.national_debt","op":"add","value":6000000000.0}]},
			{"id":"repress", "text":"سرکوب امنیتی", "consequence":"خیابان موقتاً آرام می‌شود ولی اعتماد و مشروعیت افت می‌کند.", "effects":[
				{"path":"politics.tension","op":"add","value":-0.04,"min":0.0,"max":1.0},
				{"path":"politics.trust","op":"add","value":-0.08,"min":0.0,"max":1.0},
				{"path":"politics.legitimacy","op":"add","value":-0.05,"min":0.0,"max":1.0}]}
		]
	},
	"debt_crisis": {
		"title": "بحران بدهی دولت",
		"description": "هزینه بهره و کسری، توان مالی دولت را تهدید می‌کند. هر راه‌حل بر رشد و رفاه اثر متفاوت دارد.",
		"choices": [
			{"id":"austerity", "text":"ریاضت و کاهش هزینه", "consequence":"بدهی کاهش می‌یابد اما شادی و رشد افت می‌کند.", "effects":[
				{"path":"economy.national_debt","op":"mul","value":0.94,"min":0.0},
				{"path":"population.happiness","op":"add","value":-0.04,"min":0.0,"max":1.0},
				{"path":"economy.growth_rate","op":"add","value":-0.004,"min":-0.05,"max":0.08}]},
			{"id":"tax", "text":"اصلاح مالیاتی تدریجی", "consequence":"درآمد پایدارتر می‌شود ولی رضایت کوتاه‌مدت کم می‌شود.", "effects":[
				{"path":"economy.tax_rate","op":"add","value":0.03,"min":0.0,"max":0.9},
				{"path":"politics.trust","op":"add","value":-0.015,"min":0.0,"max":1.0}]},
			{"id":"restructure", "text":"مذاکره برای بازسازی بدهی", "consequence":"بخشی از بدهی سبک می‌شود ولی اعتبار بازار افت می‌کند.", "effects":[
				{"path":"economy.national_debt","op":"mul","value":0.90,"min":0.0},
				{"path":"stock_market.investor_confidence","op":"add","value":-0.08,"min":0.0,"max":1.0}]}
		]
	},
	"border_tension": {
		"title": "تنش مرزی",
		"description": "تحرکات نظامی در مرز افزایش یافته و احتمال اشتباه محاسباتی وجود دارد.",
		"choices": [
			{"id":"diplomacy", "text":"خط تماس و مذاکره فوری", "consequence":"تنش کاهش می‌یابد و نفوذ دیپلماتیک تقویت می‌شود.", "effects":[
				{"path":"politics.tension","op":"add","value":-0.035,"min":0.0,"max":1.0},
				{"path":"diplomacy.influence","op":"add","value":3.0,"min":0.0,"max":100.0}]},
			{"id":"mobilize", "text":"آماده‌باش محدود", "consequence":"بازدارندگی بالا می‌رود اما هزینه و تنش افزایش می‌یابد.", "effects":[
				{"path":"military.readiness","op":"add","value":0.06,"min":0.0,"max":1.0},
				{"path":"politics.tension","op":"add","value":0.025,"min":0.0,"max":1.0},
				{"path":"economy.national_debt","op":"add","value":1500000000.0}]},
			{"id":"ignore", "text":"عدم واکنش", "consequence":"هزینه‌ای ندارد ولی آمادگی و اعتماد عمومی کاهش می‌یابد.", "effects":[
				{"path":"military.readiness","op":"add","value":-0.04,"min":0.0,"max":1.0},
				{"path":"population.happiness","op":"add","value":-0.015,"min":0.0,"max":1.0}]}
		]
	},
	"cyber_attack": {
		"title": "حمله سایبری به زیرساخت‌ها",
		"description": "شبکه‌های حیاتی هدف حمله هماهنگ قرار گرفته‌اند و خدمات عمومی ناپایدار شده‌اند.",
		"choices": [
			{"id":"counter", "text":"پاسخ فنی و ضدحمله محدود", "consequence":"آمادگی سایبری بالا می‌رود اما هزینه امنیتی دارد.", "effects":[
				{"path":"intelligence.cyber_readiness","op":"add","value":0.09,"min":0.0,"max":1.0},
				{"path":"security.cyber","op":"add","value":0.07,"min":0.0,"max":1.0},
				{"path":"economy.national_debt","op":"add","value":1800000000.0}]},
			{"id":"isolate", "text":"قطع موقت شبکه‌های حساس", "consequence":"خسارت مهار می‌شود اما اقتصاد دیجیتال کند می‌شود.", "effects":[
				{"path":"infrastructure.quality","op":"add","value":-0.01,"min":0.0,"max":1.0},
				{"path":"economy.growth_rate","op":"add","value":-0.002,"min":-0.05,"max":0.08}]},
			{"id":"conceal", "text":"پنهان‌کردن حادثه", "consequence":"آرامش کوتاه‌مدت حفظ می‌شود ولی ریسک نفوذ بالا می‌رود.", "effects":[
				{"path":"intelligence.infiltration_risk","op":"add","value":0.08,"min":0.0,"max":1.0},
				{"path":"politics.trust","op":"add","value":-0.025,"min":0.0,"max":1.0}]}
		]
	},
	"natural_disaster": {
		"title": "بلای طبیعی بزرگ",
		"description": "زیرساخت و سکونتگاه‌ها آسیب دیده‌اند و زمان واکنش بر تلفات و اعتماد عمومی اثر می‌گذارد.",
		"choices": [
			{"id":"full_response", "text":"بسیج ملی امداد", "consequence":"واکنش سریع و پرهزینه، آمادگی آینده را بالا می‌برد.", "effects":[
				{"path":"emergency.preparedness","op":"add","value":0.08,"min":0.0,"max":1.0},
				{"path":"population.happiness","op":"add","value":0.02,"min":0.0,"max":1.0},
				{"path":"economy.national_debt","op":"add","value":5000000000.0}]},
			{"id":"regional", "text":"واگذاری به دولت‌های محلی", "consequence":"هزینه کمتر است؛ نتیجه به کارآمدی محلی وابسته می‌ماند.", "effects":[
				{"path":"administration.decentralization","op":"add","value":0.04,"min":0.0,"max":1.0},
				{"path":"emergency.response_time","op":"add","value":-0.5,"min":1.0,"max":60.0}]},
			{"id":"delay", "text":"تعویق بازسازی", "consequence":"بدهی مهار می‌شود ولی کیفیت زیرساخت و اعتماد افت می‌کند.", "effects":[
				{"path":"infrastructure.quality","op":"add","value":-0.04,"min":0.0,"max":1.0},
				{"path":"politics.trust","op":"add","value":-0.04,"min":0.0,"max":1.0}]}
		]
	},
	"trade_deficit_crisis": {
		"title": "کسری شدید تجاری",
		"description": "واردات از صادرات پیشی گرفته و فشار بر ارز و ذخایر خارجی رو به افزایش است.",
		"choices": [
			{"id":"export", "text":"مشوق هدفمند صادرات", "consequence":"صادرات و صنعت تقویت می‌شود اما دولت هزینه می‌کند.", "effects":[
				{"path":"trade.exports","op":"mul","value":1.04,"min":0.0},
				{"path":"industry.productivity","op":"add","value":0.015,"min":0.0,"max":1.0},
				{"path":"economy.national_debt","op":"add","value":2200000000.0}]},
			{"id":"tariff", "text":"تعرفه موقت واردات", "consequence":"واردات کم می‌شود ولی تورم افزایش می‌یابد.", "effects":[
				{"path":"trade.tariff_rate","op":"add","value":0.04,"min":0.0,"max":0.8},
				{"path":"trade.imports","op":"mul","value":0.97,"min":0.0},
				{"path":"economy.inflation","op":"add","value":0.01,"min":-0.02,"max":0.5}]},
			{"id":"currency", "text":"تعدیل نرخ ارز", "consequence":"رقابت صادراتی بهتر و قدرت خرید کمتر می‌شود.", "effects":[
				{"path":"central_bank.exchange_rate","op":"mul","value":1.06,"min":0.01},
				{"path":"population.happiness","op":"add","value":-0.02,"min":0.0,"max":1.0}]}
		]
	},
	"housing_crisis": {
		"title": "بحران مسکن",
		"description": "عرضه مسکن از تشکیل خانوار عقب مانده و فشار اجاره، جوانان و خانواده‌ها را تحت تأثیر قرار داده است.",
		"choices": [
			{"id":"build", "text":"طرح ملی ساخت مسکن", "consequence":"عرضه و رضایت بالا می‌رود اما بدهی سنگین‌تر می‌شود.", "effects":[
				{"path":"physical.housing_units","op":"add","value":350000.0,"min":0.0},
				{"path":"population.happiness","op":"add","value":0.025,"min":0.0,"max":1.0},
				{"path":"economy.national_debt","op":"add","value":7000000000.0}]},
			{"id":"rent", "text":"حمایت اجاره و وام هدفمند", "consequence":"فشار کوتاه‌مدت کاهش می‌یابد ولی ریشه کمبود باقی می‌ماند.", "effects":[
				{"path":"households_detail_full.housing_own","op":"add","value":0.015,"min":0.0,"max":1.0},
				{"path":"welfare.poverty","op":"add","value":-0.01,"min":0.0,"max":1.0},
				{"path":"economy.national_debt","op":"add","value":2500000000.0}]},
			{"id":"deregulate", "text":"آزادسازی ساخت‌وساز", "consequence":"عرضه ارزان‌تر می‌شود اما گسترش بی‌رویه شهری بالا می‌رود.", "effects":[
				{"path":"physical.housing_units","op":"add","value":180000.0,"min":0.0},
				{"path":"settlements_detail.sprawl","op":"add","value":0.04,"min":0.0,"max":1.0}]}
		]
	},
	"snow_transport_crisis": {
		"title":"بحران برف و انسداد راه‌ها",
		"description":"برف سنگین از ظرفیت شهرداری عبور کرده و رفت‌وآمد، امداد و زنجیره تأمین مختل شده است.",
		"choices":[
			{"id":"emergency_clearance","text":"قرارداد اضطراری برف‌روبی","consequence":"راه‌ها سریع‌تر باز می‌شوند اما بدهی افزایش می‌یابد.","effects":[
				{"path":"municipal_services.roads_blocked","op":"add","value":-0.45,"min":0,"max":1},
				{"path":"economy.national_debt","op":"add","value":3000000000}]},
			{"id":"mobilize","text":"بسیج ارتش و نیروهای امدادی","consequence":"انسداد کاهش می‌یابد اما آمادگی نظامی افت می‌کند.","effects":[
				{"path":"municipal_services.roads_blocked","op":"add","value":-0.30,"min":0,"max":1},
				{"path":"military.readiness","op":"add","value":-0.03,"min":0.1,"max":1},
				{"path":"politics.trust","op":"add","value":0.01,"min":0,"max":1}]},
			{"id":"wait","text":"انتظار برای بهبود هوا","consequence":"هزینه فوری ندارد ولی اعتراض و نارضایتی تشدید می‌شود.","effects":[
				{"path":"population.happiness","op":"add","value":-0.03,"min":0.05,"max":0.95},
				{"path":"politics.tension","op":"add","value":0.05,"min":0,"max":1}]}
		]
	},
	"urban_flood": {
		"title":"سیلاب و آب‌گرفتگی شهری","description":"بارش شدید، ضعف زهکشی و انسداد مسیرها به خانه‌ها و کسب‌وکارها آسیب زده است.",
		"choices":[
			{"id":"pump","text":"تخلیه اضطراری و پمپ سیار","consequence":"راه‌ها باز می‌شوند و هزینه مالی ایجاد می‌شود.","effects":[{"path":"municipal_services.roads_blocked","op":"add","value":-0.35,"min":0,"max":1},{"path":"economy.national_debt","op":"add","value":2200000000}]},
			{"id":"rebuild","text":"بازسازی زهکشی","consequence":"راه‌حل پایدارتر ولی گران‌تر است.","effects":[{"path":"municipal_services.drainage","op":"add","value":0.08,"min":0,"max":1},{"path":"economy.national_debt","op":"add","value":4500000000}]},
			{"id":"local","text":"واگذاری به شهرداری‌های محلی","consequence":"هزینه کمتر، اما اعتماد عمومی اندکی افت می‌کند.","effects":[{"path":"administration.decentralization","op":"add","value":0.03,"min":0,"max":1},{"path":"politics.trust","op":"add","value":-0.01,"min":0,"max":1}]}
		]
	},
	"heatwave_crisis": {
		"title":"موج گرمای شدید","description":"تقاضای آب و برق افزایش یافته و سلامت سالمندان و کارگران فضای باز در خطر است.",
		"choices":[
			{"id":"cooling","text":"مراکز خنک‌کننده اضطراری","consequence":"تلفات و نارضایتی کم می‌شود و دولت هزینه می‌کند.","effects":[{"path":"municipal_services.heat_readiness","op":"add","value":0.10,"min":0,"max":1},{"path":"health.quality","op":"add","value":0.02,"min":0,"max":1},{"path":"economy.national_debt","op":"add","value":1800000000}]},
			{"id":"ration","text":"مدیریت مصرف آب و برق","consequence":"ذخایر حفظ و رضایت کمی کاهش می‌یابد.","effects":[{"path":"resources.inventory.آب","op":"add","value":8,"min":0,"max":150},{"path":"resources.inventory.برق","op":"add","value":6,"min":0,"max":200},{"path":"population.happiness","op":"add","value":-0.01,"min":0.05,"max":0.95}]},
			{"id":"ignore","text":"ادامه روال عادی","consequence":"هزینه ندارد ولی سلامت و اعتماد آسیب می‌بیند.","effects":[{"path":"health.quality","op":"add","value":-0.03,"min":0,"max":1},{"path":"politics.trust","op":"add","value":-0.02,"min":0,"max":1}]}
		]
	},
	"heating_crisis": {
		"title":"کمبود گرمایش زمستانی","description":"کمبود برق و گاز، خانه‌ها و مراکز درمانی را در سرمای شدید تحت فشار قرار داده است.",
		"choices":[
			{"id":"import_energy","text":"واردات اضطراری انرژی","consequence":"گرمایش تأمین و بدهی افزایش می‌یابد.","effects":[{"path":"resources.inventory.برق","op":"add","value":15,"min":0,"max":200},{"path":"resources.inventory.گاز","op":"add","value":15,"min":0,"max":150},{"path":"economy.national_debt","op":"add","value":2800000000}]},
			{"id":"priority","text":"اولویت بیمارستان‌ها و خانه‌ها","consequence":"سلامت حفظ ولی صنعت با افت تولید روبه‌رو می‌شود.","effects":[{"path":"health.quality","op":"add","value":0.015,"min":0,"max":1},{"path":"industry.output","op":"mul","value":0.98,"min":0}]},
			{"id":"ration_heat","text":"سهمیه‌بندی گرمایش","consequence":"ذخایر حفظ ولی شادی مردم کاهش می‌یابد.","effects":[{"path":"resources.inventory.گاز","op":"add","value":7,"min":0,"max":150},{"path":"population.happiness","op":"add","value":-0.025,"min":0.05,"max":0.95}]}
		]
	},
	"brain_drain": {
		"title": "موج مهاجرت نخبگان",
		"description": "پژوهشگران و متخصصان بیشتری در حال خروج‌اند و ظرفیت فناوری و مدیریت کشور تهدید می‌شود.",
		"choices": [
			{"id":"research", "text":"افزایش حمایت پژوهشی", "consequence":"خروج نخبگان کم و توان فناوری بیشتر می‌شود؛ هزینه مالی دارد.", "effects":[
				{"path":"elites_detail.brain_drain","op":"add","value":-0.05,"min":0.0,"max":1.0},
				{"path":"technology.research_rate","op":"add","value":1.5,"min":0.0},
				{"path":"economy.national_debt","op":"add","value":2000000000.0}]},
			{"id":"freedom", "text":"اصلاح فضای علمی و اجتماعی", "consequence":"اعتماد و ماندگاری نخبگان بالا می‌رود ولی تنش سیاسی کوتاه‌مدت ممکن است.", "effects":[
				{"path":"elites_detail.brain_drain","op":"add","value":-0.035,"min":0.0,"max":1.0},
				{"path":"culture.media_freedom","op":"add","value":0.04,"min":0.0,"max":1.0},
				{"path":"politics.tension","op":"add","value":0.01,"min":0.0,"max":1.0}]},
			{"id":"ignore", "text":"عدم مداخله", "consequence":"هزینه‌ای ندارد ولی سرمایه انسانی و پژوهش افت می‌کند.", "effects":[
				{"path":"education.human_capital","op":"add","value":-0.035,"min":0.0,"max":1.0},
				{"path":"technology.research_rate","op":"add","value":-0.8,"min":0.0}]}
		]
	}
}

const ALIASES = {
	"epidemic": "epidemic_outbreak",
	"protest": "mass_protest",
	"unrest_risk": "mass_protest",
	"infrastructure_damage": "natural_disaster",
	"urban_sprawl_crisis": "housing_crisis",
	"housing_shortage_protest": "housing_crisis"
}

static func update_pending(state: Dictionary, generated_events: Array, tick: int) -> Dictionary:
	state = _expire_old(state, tick)
	var current_day = TimeManager.get_total_days(state)
	var lifetime_days = int(BalanceConfig.get_value("simulation.decision_lifetime_days", DECISION_LIFETIME))
	var pending: Array = state.get("pending_decisions", []).duplicate(true)
	var known: Dictionary = {}
	for item in pending:
		known[str(item.get("id", ""))] = true
	for wrapped in generated_events:
		if pending.size() >= MAX_PENDING:
			break
		var detail: Dictionary = wrapped.get("event", {})
		var event_type = str(detail.get("type", ""))
		event_type = ALIASES.get(event_type, event_type)
		if not TEMPLATES.has(event_type):
			continue
		var decision_id = "%s_%d_%d" % [event_type, tick, pending.size()]
		if known.has(decision_id):
			continue
		var template: Dictionary = TEMPLATES[event_type]
		pending.append({
			"id": decision_id,
			"event_type": event_type,
			"source_system": str(wrapped.get("system", "")),
			"title": template["title"],
			"description": template["description"],
			"choices": template["choices"].duplicate(true),
			"created_tick": tick,
			"created_day": current_day,
			"expires_tick": tick + int(ceil(float(lifetime_days) / 30.0)),
			"expires_day": current_day + lifetime_days
		})
		known[decision_id] = true
	state["pending_decisions"] = pending
	return state

static func resolve_decision(state: Dictionary, decision_id: String, choice_id: String, status: String = "resolved") -> Dictionary:
	var pending: Array = state.get("pending_decisions", []).duplicate(true)
	var selected_index = -1
	var selected: Dictionary = {}
	for i in range(pending.size()):
		if str(pending[i].get("id", "")) == decision_id:
			selected_index = i
			selected = pending[i]
			break
	if selected_index < 0:
		return {"success": false, "reason": "تصمیم موردنظر دیگر فعال نیست", "state": state}
	var choice: Dictionary = {}
	for item in selected.get("choices", []):
		if str(item.get("id", "")) == choice_id:
			choice = item
			break
	if choice.is_empty():
		return {"success": false, "reason": "گزینه تصمیم معتبر نیست", "state": state}
	for effect in choice.get("effects", []):
		_apply_effect(state, effect)
	pending.remove_at(selected_index)
	state["pending_decisions"] = pending
	var history: Array = state.get("decision_history", []).duplicate(true)
	history.append({
		"decision_id": decision_id,
		"title": selected.get("title", ""),
		"choice_id": choice_id,
		"choice_text": choice.get("text", ""),
		"consequence": choice.get("consequence", ""),
		"resolved_tick": state.get("tick", 0),
		"resolved_day": TimeManager.get_total_days(state),
		"status": status
	})
	while history.size() > MAX_HISTORY:
		history.pop_front()
	state["decision_history"] = history
	return {"success": true, "state": state, "decision": selected, "choice": choice}

static func validate_choice(state: Dictionary, decision_id: String, choice_id: String) -> bool:
	for decision in state.get("pending_decisions", []):
		if str(decision.get("id", "")) != decision_id:
			continue
		for choice in decision.get("choices", []):
			if str(choice.get("id", "")) == choice_id:
				return true
	return false

static func _expire_old(state: Dictionary, tick: int) -> Dictionary:
	var expired_ids: Array = []
	var current_day = TimeManager.get_total_days(state)
	for decision in state.get("pending_decisions", []):
		if not decision.has("expires_day"):
			# schema قدیمی، expires_tick را روز مطلق نگه می‌داشت.
			decision["expires_day"] = int(decision.get("expires_tick", current_day + DECISION_LIFETIME))
			decision["expires_tick"] = tick + int(ceil(float(max(0, int(decision["expires_day"]) - current_day)) / 30.0))
		if int(decision.get("expires_day", current_day + 1)) <= current_day:
			expired_ids.append(str(decision.get("id", "")))
	for decision_id in expired_ids:
		var pending: Array = state.get("pending_decisions", [])
		for decision in pending:
			if str(decision.get("id", "")) == decision_id:
				var choices: Array = decision.get("choices", [])
				if not choices.is_empty():
					state = resolve_decision(state, decision_id, str(choices[-1].get("id", "")), "expired").state
				break
	return state

static func _apply_effect(state: Dictionary, effect: Dictionary):
	var parts = str(effect.get("path", "")).split(".")
	if parts.is_empty():
		return
	var current = state
	for i in range(parts.size() - 1):
		if not current is Dictionary or not current.has(parts[i]):
			return
		current = current[parts[i]]
	var key = parts[-1]
	if not current is Dictionary or not current.has(key):
		return
	var old_value = current[key]
	if not (old_value is int or old_value is float):
		return
	var new_value = float(old_value)
	match str(effect.get("op", "add")):
		"mul": new_value *= float(effect.get("value", 1.0))
		"set": new_value = float(effect.get("value", new_value))
		_: new_value += float(effect.get("value", 0.0))
	if effect.has("min"):
		new_value = max(new_value, float(effect["min"]))
	if effect.has("max"):
		new_value = min(new_value, float(effect["max"]))
	current[key] = new_value
