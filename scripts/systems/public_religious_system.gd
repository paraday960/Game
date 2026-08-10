extends BaseSystem
# ۳.۵۱ اماکن عمومی و مذهبی - پارک، مسجد، کلیسا، معبد
func compute(state: Dictionary, tick: int) -> Dictionary:
    var places=state.get("public_religious",{})
    places["parks"]=places.get("parks",3000)
    places["mosques"]=places.get("mosques",60000)
    places["churches"]=places.get("churches",300)
    places["temples"]=places.get("temples",100)
    places["green_space_per_capita"]=places.get("green_space_per_capita",15.0)
    places["access"]=places.get("access",0.70)
    places["maintenance"]=places.get("maintenance",0.60)
    var events=[]
    var pop=state.get("population",{}).get("total",85_000_000)
    places["green_space_per_capita"]=clamp(places["parks"]*5000.0/pop*1000.0, 2.0, 50.0)
    places["access"]=clamp(places["access"]+Deterministic.next_range(-0.001,0.002),0.3,0.95)
    if places["green_space_per_capita"]<5.0 and Deterministic.chance(0.01):
        events.append({"type":"green_space_crisis","message":"کمبود فضای سبز سرانه - شهرها بتنی"})
    state["public_religious"]=places
    return {"success":true,"state":state,"events":events}

cat > scripts/systems/government_buildings_system.gd <<'GD'
extends BaseSystem
# ۳.۵۲ نهادهای دولتی - وزارتخانه، شهرداری، دادگاه، سفارت
func compute(state: Dictionary, tick: int) -> Dictionary:
    var gov=state.get("government_buildings",{})
    gov["ministries"]=gov.get("ministries",20)
    gov["municipalities"]=gov.get("municipalities",1200)
    gov["courts"]=gov.get("courts",400)
    gov["embassies"]=gov.get("embassies",100)
    gov["digital_government"]=gov.get("digital_government",0.50)
    gov["efficiency"]=gov.get("efficiency",0.60)
    var events=[]
    var tech=state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)
    gov["digital_government"]=clamp(gov["digital_government"]+tech*0.001,0.2,0.95)
    gov["efficiency"]=clamp(gov["efficiency"]+gov["digital_government"]*0.0005,0.2,0.95)
    if gov["efficiency"]<0.4 and Deterministic.chance(0.01):
        events.append({"type":"gov_inefficiency","message":"ناکارآمدی نهادهای دولتی - صف‌های طولانی"})
    state["government_buildings"]=gov
    return {"success":true,"state":state,"events":events}

cat > scripts/systems/citizens_system.gd <<'GD'
extends BaseSystem
# ۳.۵۳ شهروندان - نمونه ۱۰۰۰ نفر با ویژگی سن، جنسیت، مهارت، شغل، رضایت
func compute(state: Dictionary, tick: int) -> Dictionary:
    var citizens=state.get("citizens_detail",{})
    citizens["sample_size"]=citizens.get("sample_size",1000)
    citizens["avg_age"]=citizens.get("avg_age",35.0)
    citizens["avg_happiness"]=citizens.get("avg_happiness",state.get("population",{}).get("happiness",0.60))
    citizens["diversity_index"]=citizens.get("diversity_index",0.60)
    citizens["social_mobility"]=citizens.get("social_mobility",0.50)
    var events=[]
    var pop=state.get("population",{})
    citizens["avg_happiness"]=pop.get("happiness",0.60)
    citizens["social_mobility"]=clamp(citizens["social_mobility"]+state.get("education",{}).get("quality",0.55)*0.0005 - state.get("welfare",{}).get("gini",0.38)*0.0003,0.1,0.90)
    if citizens["social_mobility"]<0.3 and Deterministic.chance(0.01):
        events.append({"type":"low_mobility","message":"تحرک اجتماعی پایین - فقر موروثی"})
    state["citizens_detail"]=citizens
    return {"success":true,"state":state,"events":events}

cat > scripts/ai/public_religious_ai.gd <<'GD'
extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    return []
