extends BaseSystem
# ۳.۵۴ نیروی کار و مشاغل - تفصیلی مشاغل و دستمزد
func compute(state: Dictionary, tick: int) -> Dictionary:
    var workforce=state.get("workforce_detail",{})
    workforce["total"]=workforce.get("total",state.get("population",{}).get("workforce",55000000))
    workforce["farmers"]=workforce.get("farmers",0.20)
    workforce["industrial"]=workforce.get("industrial",0.25)
    workforce["services"]=workforce.get("services",0.35)
    workforce["gov"]=workforce.get("gov",0.15)
    workforce["unemployed"]=workforce.get("unemployed",state.get("economy",{}).get("unemployment",0.08))
    workforce["avg_wage"]=workforce.get("avg_wage",state.get("economy",{}).get("gdp_per_capita",5000.0)*0.8)
    workforce["productivity"]=workforce.get("productivity",0.60)
    var events=[]
    var econ=state.get("economy",{})
    var edu=state.get("education",{})
    # بهره‌وری = f(آموزش، سلامت، رضایت)
    var prod_target=0.5+edu.get("quality",0.55)*0.2+state.get("health",{}).get("quality",0.60)*0.1+state.get("population",{}).get("happiness",0.6)*0.2
    workforce["productivity"]=clamp(workforce["productivity"]*0.99+prod_target*0.01,0.2,0.95)
    # دستمزد با بهره‌وری و تورم
    workforce["avg_wage"]*= (1.0 + econ.get("growth_rate",0.02)/365.0 + econ.get("inflation",0.08)/365.0*0.5)
    # بیکاری
    workforce["unemployed"]=econ.get("unemployment",0.08)
    # ترکیب شغلی با فناوری
    var tech=state.get("technology",{}).get("branches",{}).get("دیجیتال",0.20)
    if tech>0.4:
        workforce["farmers"]=clamp(workforce["farmers"]-0.0001,0.05,0.40)
        workforce["services"]+=0.0001
    state["workforce_detail"]=workforce
    return {"success":true,"state":state,"events":events}

cat > scripts/systems/officials_managers_system.gd <<'GD'
extends BaseSystem
# ۳.۵۵ دولتمردان و مدیران - وزرا، استانداران، مدیران ارشد
func compute(state: Dictionary, tick: int) -> Dictionary:
    var officials=state.get("officials",{})
    officials["ministers"]=officials.get("ministers",20)
    officials["governors"]=officials.get("governors",31)
    officials["mayors"]=officials.get("mayors",1200)
    officials["senior_managers"]=officials.get("senior_managers",5000)
    officials["competence"]=officials.get("competence",0.60)
    officials["corruption"]=officials.get("corruption",state.get("politics",{}).get("corruption",0.30))
    officials["turnover"]=officials.get("turnover",0.15)
    var events=[]
    var corruption=state.get("politics",{}).get("corruption",0.30)
    var stability=state.get("politics",{}).get("stability",0.60)
    officials["competence"]=clamp(officials["competence"]+state.get("education",{}).get("quality",0.55)*0.0005 - corruption*0.0005,0.2,0.95)
    officials["corruption"]=corruption
    officials["turnover"]=clamp(0.15 + (1.0-stability)*0.2,0.05,0.50)
    if corruption>0.6 and Deterministic.chance(0.01):
        events.append({"type":"manager_corruption","message":"افشای فساد مدیران ارشد - برکناری وزیر"})
    state["officials"]=officials
    return {"success":true,"state":state,"events":events}

cat > scripts/systems/politicians_system.gd <<'GD'
extends BaseSystem
# ۳.۵۶ سیاست‌مداران - احزاب، جناح‌ها، ایدئولوژی
func compute(state: Dictionary, tick: int) -> Dictionary:
    var pols=state.get("politicians_detail",{})
    pols["parties"]=pols.get("parties",5)
    pols["factions"]=pols.get("factions",8)
    pols["ideology_diversity"]=pols.get("ideology_diversity",0.60)
    pols["polarization"]=pols.get("polarization",0.40)
    pols["populism"]=pols.get("populism",0.30)
    pols["trust_politicians"]=pols.get("trust_politicians",0.40)
    var events=[]
    var politics=state.get("politics",{})
    pols["polarization"]=clamp(pols["polarization"] + politics.get("tension",0.35)*0.001 - state.get("culture",{}).get("cohesion",0.65)*0.0005,0.1,0.90)
    pols["trust_politicians"]=clamp(pols["trust_politicians"]*0.99 + politics.get("trust",0.55)*0.01,0.1,0.85)
    pols["populism"]=clamp(pols["populism"] + (1.0-state.get("population",{}).get("happiness",0.6))*0.001,0.05,0.80)
    if pols["polarization"]>0.7 and Deterministic.chance(0.012):
        events.append({"type":"polarization_crisis","message":"قطبی‌شدن شدید سیاسی - بن‌بست در پارلمان"})
    state["politicians_detail"]=pols
    return {"success":true,"state":state,"events":events}

cat > scripts/ai/workforce_jobs_ai.gd <<'GD'
extends BaseAI
func decide(state: Dictionary, tick: int) -> Array:
    return []
